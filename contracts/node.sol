//SPDX-License-Identifier: MIT
pragma solidity >0.8.0;

interface IERC20 {
    function totalSupply() external view returns (uint);
    function balanceOf(address account) external view returns (uint);
    function transfer(address recipient, uint amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint);
    function approve(address spender, uint amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint value);
}

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor () {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}


contract Node is Ownable {
    address public constant BIN = 0x586a74A6c7375A507e3E3DdFeF891cB9D2477777;
    address public ROX;
 
    uint public totalRewards;
    uint public accRewardsPerNode;

    address[] public nodes;
    mapping(address => uint256) private addressIndex;// start from 1
    uint public lastProcessIndex;
    
    struct UserInfo {
        uint debt;
        uint claimed;
    }
    mapping(address => UserInfo) public userInfo;

    function setRox(address rox) external onlyOwner {
        ROX = rox;
    }

    function _addNode(address _addr) private {
        if (addressIndex[_addr] == 0) {
            nodes.push(_addr);
            addressIndex[_addr] = nodes.length;

            userInfo[_addr].debt = accRewardsPerNode;
        }
    }

    function addNode(address _addr) external onlyOwner {
        _addNode(_addr);
    }

    function addMultiNodes(address[] memory _addrs) external onlyOwner {
        for (uint256 i = 0; i < _addrs.length; i++) {
            _addNode(_addrs[i]);
        }
    }

    function _removeNode(address _addr) private {
        if (addressIndex[_addr] == 0) return; 
       
        uint256 index = addressIndex[_addr] - 1;
        uint256 lastIndex = nodes.length - 1;
        
        if (index != lastIndex) {
            address lastAddr = nodes[lastIndex];
            nodes[index] = lastAddr;
            addressIndex[lastAddr] = index + 1;
        }
        
        nodes.pop();
        delete addressIndex[_addr];
    }

    function removeNode(address _addr) external onlyOwner {
        _removeNode(_addr);
    }

    function removeMultiNodes(address[] memory _addrs) external onlyOwner {
        for (uint256 i = 0; i < _addrs.length; i++) {
            _removeNode(_addrs[i]);
        }
    }

    function rewardTo(uint rewards) external {
        require(msg.sender == ROX);
        uint num = nodes.length;
        if (num > 0) {
            accRewardsPerNode += rewards / num;
        }
    }

    function process() external {
        uint nodeNum = nodes.length;
        if (nodeNum == 0) return;
        uint256 _lastProcessedIndex = lastProcessIndex;
        for (uint i; i < 10; i++) {
            _lastProcessedIndex++;
            if(_lastProcessedIndex >= nodeNum) {
                _lastProcessedIndex = 0;
            }
            address user = nodes[_lastProcessedIndex];
            _claim(user);
        }
        lastProcessIndex = _lastProcessedIndex;
    }

    function pendingRewards(address user) public view returns (uint) {
        if (addressIndex[user] == 0) return 0;
        UserInfo storage ui = userInfo[user];
        return accRewardsPerNode - ui.debt;
    }

    function totalNum() public view returns (uint256) {
        return nodes.length;
    }
    
    function isNode(address _addr) public view returns (bool) {
        return addressIndex[_addr] != 0;
    }

    function claim() external {
        _claim(msg.sender);
    }

    function _claim(address user) private {
        UserInfo storage ui = userInfo[user];
        uint amount = pendingRewards(user);
        if (amount > 0) {
            IERC20(BIN).transfer(user, amount);
            ui.debt = accRewardsPerNode;
            ui.claimed += amount;
        }
    }

    function rescueETH(address to) external onlyOwner {
        payable(to).transfer(address(this).balance);
    }

    function rescueERC20(address token, address to, uint amount) external onlyOwner {
        IERC20(token).transfer(to, amount);
    }
}