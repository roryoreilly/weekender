pragma solidity ^0.5.8;

import'openzeppelin-solidity/contracts/token/ERC20/ERC20Detailed.sol';
import'openzeppelin-solidity/contracts/ownership/Ownable.sol';
import'openzeppelin-solidity/contracts/math/SafeMath.sol';

contract Weekender is ERC20Detailed, Ownable {
    using SafeMath for uint256;

    mapping(address => uint256) public _balances;
    mapping(address => uint256) private _lastAppliedInterest;
    mapping (address => mapping (address => uint256)) private _allowances;

    uint256 private _totalSupply;
    uint256 contractStarted;

    string constant TOKEN_NAME = 'Weekender';
    string constant TOKEN_SYMBOL = 'WKR';
    uint8 constant TOKEN_DECIMALS = 18;
    uint constant TOKEN_SUPPLY = 1000000;
    int constant INTEREST_WEEKDAY = 2000000;
    int constant INTEREST_WEEKEND = 5000000;
    uint constant INTEREST_BASE = 100000000;
    uint constant DAY_IN_SECONDS = 86400;
    uint constant HOUR_IN_SECONDS = 3600;
    uint constant WEEK_IN_HOURS = 168;

    constructor() public payable ERC20Detailed(TOKEN_NAME, TOKEN_SYMBOL, TOKEN_DECIMALS) {
        _mint(msg.sender, TOKEN_SUPPLY, now);
    }

    function totalSupply() public view returns (uint256) {
        return _balanceWithInterest(TOKEN_SUPPLY, contractStarted);
    }

    function balanceOf(address owner) public view returns (uint256) {
        return _balanceWithInterest(_balances[owner], _lastAppliedInterest[owner]);
    }

    function lastAppliedInterest(address owner) public view returns (uint256) {
        return _lastAppliedInterest[owner];
    }

    function _resetBalance(address owner) private {
        _balances[owner] = _balanceWithInterest(
            _balances[owner], _lastAppliedInterest[owner]);
        _lastAppliedInterest[owner] = now;
    }

    function _balanceWithInterest(
            uint256 balBeforeInterest,
            uint256 lastInterestTime)
            private view returns (uint256) {
        uint interest = uint(_calInterest(lastInterestTime)) + INTEREST_BASE;
        return (balBeforeInterest * interest) / INTEREST_BASE;
    }

    function _calInterest(uint256 lastInterestTime) public view returns (int) {
        int hrsImpact = int(_hoursDiff(lastInterestTime, now).mod(WEEK_IN_HOURS));
        int hrsSinceWeekStart = int(_hoursSinceWeekStart(lastInterestTime));
        if (hrsImpact <= hrsSinceWeekStart) {
            return INTEREST_WEEKDAY;
        } else if (hrsImpact > (hrsSinceWeekStart + 48)) {
            int interestWeekday = (hrsImpact - 48) * INTEREST_WEEKDAY;
            int interestWeekend = INTEREST_WEEKEND * 48;
            return (interestWeekday - interestWeekend) / hrsImpact;
        } else {
            int interestWeekday = hrsSinceWeekStart * INTEREST_WEEKDAY;
            int interestWeekend = (hrsImpact - hrsSinceWeekStart) * INTEREST_WEEKDAY;
            return (interestWeekday - interestWeekend) / hrsImpact;
        }
    }

    function _hoursDiff(uint startTime, uint endTime) private pure returns (uint256) {
        return endTime.sub(startTime).div(HOUR_IN_SECONDS);
    }

    function _hoursSinceWeekStart(uint time) private pure returns (uint256) {
        uint hoursToday = time.div(HOUR_IN_SECONDS).mod(24);
        uint daysSinceWeekStart = time.div(DAY_IN_SECONDS).add(3).mod(7);
        return daysSinceWeekStart.mul(24).add(hoursToday);
    }

   function _transfer(address sender, address recipient, uint256 amount) internal {
       require(sender != address(0), "ERC20: transfer from the zero address");
       require(recipient != address(0), "ERC20: transfer to the zero address");

       _resetBalance(sender);

       _balances[sender] = _balances[sender].sub(amount);
       _balances[recipient] = _balances[recipient].add(amount);
       emit Transfer(sender, recipient, amount);
   }

   function distributeToken(address[] calldata addresses, uint256 value) external onlyOwner {
        uint total = value * addresses.length;
        require(total/value == addresses.length);
        require(_balances[owner()] >= total);
        _balances[owner()] -= total;
        for (uint i = 0; i < addresses.length; i++) {
            _balances[addresses[i]] += value;
            require(_balances[addresses[i]] >= value);
            emit Transfer(owner(), addresses[i], value);
        }
    }

    /**
     * @dev See `IERC20.transfer`.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount) public returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    /**
     * @dev See `IERC20.allowance`.
     */
    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See `IERC20.approve`.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 value) public returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }

    /**
     * @dev See `IERC20.transferFrom`.
     *
     * Emits an `Approval` event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of `ERC20`;
     *
     * Requirements:
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `value`.
     * - the caller must have allowance for `sender`'s tokens of at least
     * `amount`.
     */
    function transferFrom(address sender, address recipient, uint256 amount) public returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, msg.sender, _allowances[sender][msg.sender].sub(amount));
        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to `approve` that can be used as a mitigation for
     * problems described in `IERC20.approve`.
     *
     * Emits an `Approval` event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender].add(addedValue));
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to `approve` that can be used as a mitigation for
     * problems described in `IERC20.approve`.
     *
     * Emits an `Approval` event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender].sub(subtractedValue));
        return true;
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a `Transfer` event with `from` set to the zero address.
     *
     * Requirements
     *
     * - `to` cannot be the zero address.
     */
    function _mint(address account, uint256 amount, uint256 time) internal {
        require(account != address(0), "ERC20: mint to the zero address");

        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);

        contractStarted = time;
        _lastAppliedInterest[msg.sender] = time;
    }

     /**
     * @dev Destoys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a `Transfer` event with `to` set to the zero address.
     *
     * Requirements
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 value) internal {
        require(account != address(0), "ERC20: burn from the zero address");

        _totalSupply = _totalSupply.sub(value);
        _balances[account] = _balances[account].sub(value);
        emit Transfer(account, address(0), value);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner`s tokens.
     *
     * This is internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an `Approval` event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(address owner, address spender, uint256 value) internal {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    /**
     * @dev Destoys `amount` tokens from `account`.`amount` is then deducted
     * from the caller's allowance.
     *
     * See `_burn` and `_approve`.
     */
    function _burnFrom(address account, uint256 amount) internal {
        _burn(account, amount);
        _approve(account, msg.sender, _allowances[account][msg.sender].sub(amount));
    }
}
