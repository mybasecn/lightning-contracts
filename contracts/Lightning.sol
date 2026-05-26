// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * Lightning (LTG) — BEP20 on BSC
 * - 21,000,000 fixed supply, 18 decimals
 * - No mint / no blacklist / no pause / no fees
 * - Owner can ONLY rescueToken() for non-LTG tokens (renounceable)
 */
contract Lightning {
    string  public constant name     = "Lightning";
    string  public constant symbol   = "LTG";
    uint8   public constant decimals = 18;
    uint256 public constant totalSupply = 21_000_000 * 10**18;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    address public owner;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event TokenRescued(address indexed token, address indexed to, uint256 amount);

    constructor() {
        owner = msg.sender;
        balanceOf[msg.sender] = totalSupply;
        emit OwnershipTransferred(address(0), msg.sender);
        emit Transfer(address(0), msg.sender, totalSupply);
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        require(spender != address(0), "LTG: approve to zero");
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 a = allowance[from][msg.sender];
        require(a >= amount, "LTG: insufficient allowance");
        if (a != type(uint256).max) {
            unchecked { allowance[from][msg.sender] = a - amount; }
            emit Approval(from, msg.sender, a - amount);
        }
        _transfer(from, to, amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 added) external returns (bool) {
        uint256 newA = allowance[msg.sender][spender] + added;
        allowance[msg.sender][spender] = newA;
        emit Approval(msg.sender, spender, newA);
        return true;
    }

    function decreaseAllowance(address spender, uint256 sub) external returns (bool) {
        uint256 cur = allowance[msg.sender][spender];
        require(cur >= sub, "LTG: decreased below zero");
        unchecked { allowance[msg.sender][spender] = cur - sub; }
        emit Approval(msg.sender, spender, cur - sub);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(from != address(0), "LTG: from zero");
        require(to   != address(0), "LTG: to zero");
        uint256 bal = balanceOf[from];
        require(bal >= amount, "LTG: insufficient balance");
        unchecked {
            balanceOf[from] = bal - amount;
            balanceOf[to]  += amount;
        }
        emit Transfer(from, to, amount);
    }

    // ===== Owner functions (only rescueToken; cannot touch LTG itself) =====

    modifier onlyOwner() {
        require(msg.sender == owner, "LTG: not owner");
        _;
    }

    function rescueToken(address token, address to, uint256 amount) external onlyOwner {
        require(token != address(this), "LTG: cannot rescue LTG itself");
        require(to != address(0), "LTG: rescue to zero");
        (bool ok, bytes memory data) = token.call(
            abi.encodeWithSignature("transfer(address,uint256)", to, amount)
        );
        require(ok && (data.length == 0 || abi.decode(data, (bool))), "LTG: rescue failed");
        emit TokenRescued(token, to, amount);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "LTG: new owner zero");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function renounceOwnership() external onlyOwner {
        emit OwnershipTransferred(owner, address(0));
        owner = address(0);
    }
}

