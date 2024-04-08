// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

// import { IERC20 } from "@openzeppelin/contracts@4.9.3/token/ERC20/IERC20.sol";
// import { Ownable } from "@openzeppelin/contracts@4.9.3/access/Ownable.sol";

/**
 * @title LUBE token contract
 * @dev The LUBE token has a simple tax assessed on it.
 * @notice website: https://joelube.xyz
 * @notice telegram: t.me/JoeLubeCoin
 * @notice x: https://twitter.com/JoeLubeCoin
 */
contract LUBE is IERC20, Ownable {
    /// @dev Registry of user token balances.
    mapping(address => uint256) private _balances;

    /// @dev Registry of addresses users have given allowances to.
    mapping(address => mapping(address => uint256)) private _allowances;

    /// @notice The EIP-712 typehash for the contract's domain.
    bytes32 public constant DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");

    /// @notice address of tax multisig
    address private _taxAddress;

    /// @notice address of taxed pool
    address private _taxedPoolAddress;

    /// @notice address of tax exempt address, if one is added
    address private _taxExemptAddress;

    /// @notice basis points of tax to charge (10,000 = 100%, 100 = 1%)
    uint256 private _taxBasisPoints = 150;

    /// @dev Name of the token.
    string private _name;

    /// @dev Symbol of the token.
    string private _symbol;

    /**
     * @param name_ Name of the token.
     * @param symbol_ Symbol of the token.
     * @param taxAddress_ Initial tax handler contract.
     */
    constructor(string memory name_, string memory symbol_, address taxAddress_) {
        _name = name_;
        _symbol = symbol_;
        _taxAddress = taxAddress_;

        _balances[_msgSender()] = totalSupply();

        emit Transfer(address(0), _msgSender(), totalSupply());
    }

    /**
     * @notice Get token name.
     * @return Name of the token.
     */
    function name() public view returns (string memory) {
        return _name;
    }

    /**
     * @notice Get token symbol.
     * @return Symbol of the token.
     */
    function symbol() external view returns (string memory) {
        return _symbol;
    }

    /**
     * @notice Get number of decimals used by the token.
     * @return Number of decimals used by the token.
     */
    function decimals() external pure returns (uint8) {
        return 18;
    }

    /**
     * @notice Get the maximum number of tokens.
     * @return The maximum number of tokens that will ever be in existence.
     */
    function totalSupply() public pure override returns (uint256) {
        // 69 billion, i.e. 69,000,000,000 tokens
        return 69 * 1e9 * 1e18;
    }

    /**
     * @notice Get token balance of given account.
     * @param account Address to retrieve balance for.
     * @return The number of tokens owned by `account`.
     */
    function balanceOf(address account) external view override returns (uint256) {
        return _balances[account];
    }

    /**
     * @notice Get destination wallet for taxes.
     * @return Address of the tax wallet.
     */
    function taxAddress() external view returns (address) {
        return _taxAddress;
    }

    /**
     * @notice Get the pool on which taxes are charged.
     * @return Address of the pool.
     */
    function taxedPoolAddress() external view returns (address) {
        return _taxedPoolAddress;
    }

    /**
     * @notice Get the tax exempt address.
     * @return Tax exempt address for adding liquidity.
     */
    function taxExemptAddress() external view returns (address) {
        return _taxExemptAddress;
    }

    /**
     * @notice Transfer tokens from caller's address to another.
     * @param recipient Address to send the caller's tokens to.
     * @param amount The number of tokens to transfer to recipient.
     * @return True if transfer succeeds, else an error is raised.
     */
    function transfer(address recipient, uint256 amount) external override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    /**
     * @notice Get the allowance `owner` has given `spender`.
     * @param owner The address on behalf of whom tokens can be spent by `spender`.
     * @param spender The address authorized to spend tokens on behalf of `owner`.
     * @return The allowance `owner` has given `spender`.
     */
    function allowance(address owner, address spender) external view override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @notice Approve address to spend caller's tokens.
     * @dev This method can be exploited by malicious spenders if their allowance is already non-zero. See the following
     * document for details: https://docs.google.com/document/d/1YLPtQxZu1UAvO9cZ1O2RPXBbT0mooh4DYKjA_jp-RLM/edit.
     * Ensure the spender can be trusted before calling this method if they've already been approved before. Otherwise
     * use either the `increaseAllowance`/`decreaseAllowance` functions, or first set their allowance to zero, before
     * setting a new allowance.
     * @param spender Address to authorize for token expenditure.
     * @param amount The number of tokens `spender` is allowed to spend.
     * @return True if the approval succeeds, else an error is raised.
     */
    function approve(address spender, uint256 amount) external override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    /**
     * @notice Transfer tokens from one address to another.
     * @param sender Address to move tokens from.
     * @param recipient Address to send the caller's tokens to.
     * @param amount The number of tokens to transfer to recipient.
     * @return True if the transfer succeeds, else an error is raised.
     */
    function transferFrom(address sender, address recipient, uint256 amount) external override returns (bool) {
        _transfer(sender, recipient, amount);

        uint256 currentAllowance = _allowances[sender][_msgSender()];
        require(currentAllowance >= amount, "LUBE:transferFrom:ALLOWANCE_EXCEEDED: Transfer amount exceeds allowance.");
        unchecked {
            _approve(sender, _msgSender(), currentAllowance - amount);
        }

        return true;
    }

    /**
     * @notice Increase spender's allowance.
     * @param spender Address of user authorized to spend caller's tokens.
     * @param addedValue The number of tokens to add to `spender`'s allowance.
     * @return True if the allowance is successfully increased, else an error is raised.
     */
    function increaseAllowance(address spender, uint256 addedValue) external returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender] + addedValue);

        return true;
    }

    /**
     * @notice Decrease spender's allowance.
     * @param spender Address of user authorized to spend caller's tokens.
     * @param subtractedValue The number of tokens to remove from `spender`'s allowance.
     * @return True if the allowance is successfully decreased, else an error is raised.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool) {
        uint256 currentAllowance = _allowances[_msgSender()][spender];
        require(
            currentAllowance >= subtractedValue,
            "LUBE:decreaseAllowance:ALLOWANCE_UNDERFLOW: Subtraction results in sub-zero allowance."
        );
        unchecked {
            _approve(_msgSender(), spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    /**
     * @notice Sets the taxed pool address.
     * @param poolAddress address of the constand product pool to tax
     */
    function setPoolAddress(address poolAddress) external onlyOwner {
        _taxedPoolAddress = poolAddress;
    }

    /**
     * @notice Sets the tax exempt address.
     * @param exemptAddress address of the constand product pool to tax
     */
    function setTaxExemptAddress(address exemptAddress) external onlyOwner {
        _taxExemptAddress = exemptAddress;
    }

    /**
     * @notice Approve spender on behalf of owner.
     * @param owner Address on behalf of whom tokens can be spent by `spender`.
     * @param spender Address to authorize for token expenditure.
     * @param amount The number of tokens `spender` is allowed to spend.
     */
    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "LUBE:_approve:OWNER_ZERO: Cannot approve for the zero address.");
        require(spender != address(0), "LUBE:_approve:SPENDER_ZERO: Cannot approve to the zero address.");

        _allowances[owner][spender] = amount;

        emit Approval(owner, spender, amount);
    }

    function getTax(address benefactor, address beneficiary, uint256 amount) private view returns (uint256) {
        if (benefactor == _taxExemptAddress || beneficiary == _taxExemptAddress) {
            return 0;
        }

        // Transactions between regular users (this includes contracts) aren't taxed.
        if (benefactor != _taxedPoolAddress && beneficiary != _taxedPoolAddress) {
            return 0;
        }

        // Don't tax the tax destination address, as it is pointless
        if (benefactor == _taxAddress || beneficiary == _taxAddress) {
            return 0;
        }

        return (amount * _taxBasisPoints) / 10000;
    }

    /**
     * @notice Transfer `amount` tokens from account `from` to account `to`.
     * @param from Address the tokens are moved out of.
     * @param to Address the tokens are moved to.
     * @param amount The number of tokens to transfer.
     */
    function _transfer(address from, address to, uint256 amount) private {
        require(from != address(0), "LUBE:_transfer:FROM_ZERO: Cannot transfer from the zero address.");
        require(to != address(0), "LUBE:_transfer:TO_ZERO: Cannot transfer to the zero address.");
        require(amount > 0, "LUBE:_transfer:ZERO_AMOUNT: Transfer amount must be greater than zero.");
        require(amount <= _balances[from], "LUBE:_transfer:INSUFFICIENT_BALANCE: Transfer amount exceeds balance.");

        uint256 tax = getTax(from, to, amount);
        uint256 taxedAmount = amount - tax;

        _balances[from] -= amount;
        _balances[to] += taxedAmount;

        if (tax > 0) {
            _balances[address(_taxAddress)] += tax;
            emit Transfer(from, address(_taxAddress), tax);
        }

        emit Transfer(from, to, taxedAmount);
    }
}
