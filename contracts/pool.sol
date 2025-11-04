//SPDX-License-Identifier: MIT
pragma solidity >0.8.0;

interface IERC20 {
    function totalSupply() external view returns (uint);
    function balanceOf(address account) external view returns (uint);
    function transfer(address recipient, uint amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint);
    function approve(address spender, uint amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint amount) external returns (bool);
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

interface IRouter {
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
}

interface IToken {
    function reSync(uint amount) external;
}

interface IDao {
    function inviterOf(address user) external returns (address);
    function start(uint startTime) external;
    function stakeInBy(address user, uint usdtAmount, uint rewards) external;
    function claimBy(address user, uint principal, uint actualProfit, uint rewards) external;
}

contract Pool is Ownable {
    struct ItemInfo {
        address account;
        uint amount;
        uint index;
        uint preStartTime;
        uint startTime;
        uint lockDays;
        uint interest;
        uint preAmount;
        bool isCanceled;
        bool isOut;
    }
    mapping (uint => ItemInfo) public itemInfoByIndex;
    uint public totalItemNum;

    struct UserInfo {
        uint totalIn;
        uint totalStaked;
        uint[] indexesOf;
    }
    mapping(address => UserInfo) public userInfo;

    uint public startTime;
    uint public stakeTime;
    uint public baseSupply = 300 * 1e18; 
    uint public addPerDay = 20 * 1e18;
    mapping(uint => uint) public preStakedPerDay;
    mapping(uint => uint) public stakedPerM; 
    uint public minToken = 100 * 1e18;
    uint public maxToken = 10000 * 1e18;
    uint public totalPreAmount;
    uint public lastProcessIndex;
    uint public slippage = 1;
    
    address public ROX;
    address constant public ROUTER = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
    address constant public USDT = 0x55d398326f99059fF775485246999027B3197955;
    address constant public BIN = 0x55d398326f99059fF775485246999027B3197955;
    address public DAO = 0x55d398326f99059fF775485246999027B3197955;

    uint256 public constant SECONDS_PER_DAY = 86400;
    uint256 public constant WAD = 1e18;

    uint public totalStakedNet;
    uint public totalRedeemedNet;

    constructor() {
        IERC20(USDT).approve(ROUTER, type(uint).max);
        IERC20(BIN).approve(ROUTER, type(uint).max);
    }

    function init(address rox, address dao) public onlyOwner {
        ROX = rox;
        DAO = dao;
        IERC20(rox).approve(ROUTER, type(uint).max);
    }

    function setStartTime(uint _timeStamp) external onlyOwner {
        startTime = _timeStamp;
    }

    function setStakeTime(uint _stakeTime) external onlyOwner {
        stakeTime = _stakeTime;
        IDao(DAO).start(_stakeTime);
    }

    function setBaseSupply(uint _baseSupply) external onlyOwner {
        baseSupply = _baseSupply;
    }

    function setSlippage(uint _slippage) external onlyOwner {
        slippage = _slippage;
    }

    function setAddPerDay(uint _addPerDay) external onlyOwner {
        addPerDay = _addPerDay;
    }

    function setMinAndMaxToken(uint _minToken, uint _maxToken) external onlyOwner {
        minToken = _minToken;
        maxToken = _maxToken;
    }

    function getPassedDays() public view returns (uint) {
        return (block.timestamp - startTime) / 1 days;
    }

    function getPassedStakeDays() public view returns (uint) {
        return (block.timestamp - stakeTime) / 1 days;
    }

    function getPreStakedToday() public view returns (uint) {
        uint d = getPassedDays();
        return preStakedPerDay[d];
    }

    function getMaxPerTx() public view returns (uint) {
        uint d = getPassedDays();
        return baseSupply + addPerDay * d;
    }

    function getMaxStakedPerTx() public view returns (uint) {
        uint d = getPassedStakeDays();
        return baseSupply + addPerDay * d;
    }

    function canCancel(uint index) public view returns (bool) {
        ItemInfo storage ii = itemInfoByIndex[index];
        uint leftTime = getSingleEstimateTime(index);
        if (ii.amount == 0 
            || ii.isCanceled 
            || ii.startTime > 0
            || ii.isOut
            || leftTime < 1 days
        ) {
            return false;
        } else {
            return true;
        }
    }

    function cancelItem(uint index) external {
        require(canCancel(index));
        ItemInfo storage ii = itemInfoByIndex[index];
        require(msg.sender == ii.account);
        ii.isCanceled = true;
        IERC20(USDT).transfer(ii.account, ii.amount);

        totalPreAmount -= ii.amount;
        userInfo[msg.sender].totalIn -= ii.amount;
    }

    function stake(uint usdtAmount, uint lockDays) external {
        require(startTime > 0);
        require(tx.origin == msg.sender);
        require(usdtAmount >= minToken);
        require(usdtAmount <= getMaxPerTx());
        require(lockDays == 1 || lockDays == 15 || lockDays == 30);
        UserInfo storage ui = userInfo[msg.sender];
        require(ui.totalIn + usdtAmount <= maxToken);
        address inviter = IDao(DAO).inviterOf(msg.sender);
        require(inviter != address(0));

        _processPreItem();

        ui.totalIn += usdtAmount;
        
        uint curDay = getPassedDays();
        preStakedPerDay[curDay] += usdtAmount;
 
        IERC20(USDT).transferFrom(msg.sender, address(this), usdtAmount);
    
        totalItemNum++;
        ItemInfo memory ii;
        ii.account = msg.sender;
        ii.amount = usdtAmount;
        ii.index = totalItemNum;
        ii.preStartTime = block.timestamp;
        ii.startTime = 0;
        ii.lockDays = lockDays;
        ii.interest = 0;
        ii.preAmount = totalPreAmount;
        ii.isCanceled = false;
        ii.isOut = false;
        itemInfoByIndex[totalItemNum] = ii;
        ui.indexesOf.push(totalItemNum);

        totalPreAmount += usdtAmount;
	}

    function _processPreItem() private {
        if (stakeTime == 0) return;
        uint nextIndex = lastProcessIndex + 1;
        for (uint i = nextIndex; i <= totalItemNum; i++) {
            if (itemInfoByIndex[i].isCanceled) {
                nextIndex++;
            } else {
                break;
            }
        }
        if (nextIndex > totalItemNum) return;
        uint curM = block.timestamp / 1 minutes;
        ItemInfo storage ii = itemInfoByIndex[nextIndex];
        if (stakedPerM[curM] + ii.amount > getMaxStakedPerTx()) {
            return;
        }
        _processStake(nextIndex);

        lastProcessIndex = nextIndex;
        stakedPerM[curM] += ii.amount;
    }

    function _processStake(uint index) private {
        ItemInfo storage ii = itemInfoByIndex[index];
        ii.startTime = block.timestamp;
        uint usdtAmount = ii.amount;
        totalStakedNet += usdtAmount;
        userInfo[ii.account].totalStaked += usdtAmount;

        uint rate = 30;
        if (ii.lockDays == 15) {
            rate = 1438;
        } else if (ii.lockDays == 30) {
            rate = 5631;
        }
        uint interest = usdtAmount * rate / 10000;
        ii.interest = interest;
        uint rewards = interest * 15 / 100;
        IERC20(USDT).transfer(DAO, rewards);
        IDao(DAO).stakeInBy(ii.account, ii.amount, rewards);
    
        _addLiquidity(usdtAmount - rewards);
    }

    function processPreItem() external {
        _processPreItem();
    }

    function _addLiquidity(uint usdtAmount) private {
        // generate the uniswap pair path of token -> usdt
        address[] memory path = new address[](2);
        path[0] = USDT;
        path[1] = BIN;
        uint[] memory amountOuts = IRouter(ROUTER).getAmountsOut(usdtAmount, path);
        uint minAmount = amountOuts[1] * (100 - slippage) / 100;

        uint binReceived = IERC20(BIN).balanceOf(address(this));
        // make the swap
        IRouter(ROUTER).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            usdtAmount,
            minAmount,
            path,
            address(this),
            block.timestamp
        );
        binReceived = IERC20(BIN).balanceOf(address(this)) - binReceived;

        uint half = binReceived / 2;
        path[0] = BIN;
        path[1] = ROX;
        amountOuts = IRouter(ROUTER).getAmountsOut(half, path);
        minAmount = amountOuts[1] * (100 - slippage) / 100;
        uint roxReceived = IERC20(ROX).balanceOf(address(this));
        IRouter(ROUTER).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            half,
            minAmount,
            path,
            address(this),
            block.timestamp
        );
        roxReceived = IERC20(ROX).balanceOf(address(this)) - roxReceived;

        IRouter(ROUTER).addLiquidity(
            ROX,
            BIN,
            roxReceived,
            half,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            address(0),
            block.timestamp
        );
    }

    function pendingReward(uint index) public view returns (uint) {
       ItemInfo storage ii = itemInfoByIndex[index];
       if (ii.startTime == 0 || ii.isOut || ii.isCanceled) return 0;

       uint rate = WAD * 3 / 1000;
       uint maxTime = 1 days; 
       if (ii.lockDays == 15) {
            rate = WAD * 9 / 1000;
            maxTime = 15 days; 
       } else if (ii.lockDays == 30) {
            rate = WAD * 15 / 1000;
            maxTime = 30 days; 
       }

       uint compRate = calculateCompoundedRate(rate, ii.startTime, block.timestamp, maxTime);
       return ii.amount * compRate / WAD; 
    }
    
    function calculateCompoundedRate(
        uint256 rate,
        uint256 lastUpdateTimestamp,
        uint256 currentTimestamp,
        uint256 maxTime
    ) public pure returns (uint256) {
        uint256 exp = currentTimestamp - lastUpdateTimestamp;

        if (exp == 0) {
            return WAD;
        }

        if (exp > maxTime) {
            exp = maxTime;
        }

        uint256 expMinusOne;
        uint256 expMinusTwo;
        uint256 basePowerTwo;
        uint256 basePowerThree;
        unchecked {
            expMinusOne = exp - 1;

            expMinusTwo = exp > 2 ? exp - 2 : 0;

            basePowerTwo = rate * rate / (SECONDS_PER_DAY * SECONDS_PER_DAY) / WAD;
            basePowerThree = basePowerTwo * rate / SECONDS_PER_DAY / WAD;
        }

        uint256 secondTerm = exp * expMinusOne * basePowerTwo;
        unchecked {
            secondTerm /= 2;
        }
        uint256 thirdTerm = exp * expMinusOne * expMinusTwo * basePowerThree;
        unchecked {
            thirdTerm /= 6;
        }

        return WAD + (rate * exp) / SECONDS_PER_DAY + secondTerm + thirdTerm;
    }

    function claim(uint index) external {
        require(tx.origin == msg.sender);
        ItemInfo storage ii = itemInfoByIndex[index];
        require(ii.account == msg.sender);
        require(block.timestamp >= ii.startTime + ii.lockDays * 1 days);
        require(ii.startTime > 0 && !ii.isCanceled && !ii.isOut);

        totalRedeemedNet += ii.amount;

        uint interest = ii.interest;
        uint needRedeem = ii.amount + interest * 85 / 100;

        ii.isOut = true;
        
        address[] memory path = new address[](3);
        path[0] = ROX;
        path[1] = BIN;
        path[2] = USDT;
        uint bbToken = IERC20(ROX).balanceOf(address(this));
        IRouter(ROUTER).swapTokensForExactTokens(
            needRedeem, 
            bbToken, 
            path, 
            address(this), 
            block.timestamp
        );

        uint toUser = ii.amount + interest * 55 / 100;
        IERC20(USDT).transfer(msg.sender, toUser);
        IERC20(USDT).transfer(DAO, needRedeem - toUser);
        IDao(DAO).claimBy(msg.sender, ii.amount, interest * 55 / 100, needRedeem - toUser);

        uint spentToken = bbToken - IERC20(ROX).balanceOf(address(this));
        IToken(ROX).reSync(spentToken);
    }

    function rescurToken(address token, address to, uint amount) external onlyOwner {
        IERC20(token).transfer(to, amount);
    }

    function rescueETH(address to) external onlyOwner {
        payable(to).transfer(address(this).balance);
    }

    function getUserItems(address user) public view returns (ItemInfo[] memory) {
        UserInfo storage ui = userInfo[user];
        uint[] memory indexes = ui.indexesOf;

        uint len = indexes.length;
        ItemInfo[] memory items = new ItemInfo[](len);
        for (uint8 i; i < len; i++) {
            uint index = indexes[i];
            ItemInfo storage ii = itemInfoByIndex[index];
            items[i].account = ii.account;
            items[i].amount = ii.amount;
            items[i].index = ii.index;
            items[i].preStartTime = ii.preStartTime;
            items[i].startTime = ii.startTime;
            items[i].lockDays = ii.lockDays;
            items[i].interest = ii.interest;
            items[i].isCanceled = ii.isCanceled;
            items[i].isOut = ii.isOut;
        }
        return items;
    }

    function getUserItemIndexes(address user) public view returns(uint[] memory) {
        UserInfo storage ui = userInfo[user];
        return ui.indexesOf;
    }

    function getTotalStakingBalance(address user) public view returns (uint, uint) {
        UserInfo storage ui = userInfo[user];
        uint[] memory indexes = ui.indexesOf;

        uint len = indexes.length;
        uint totalBalance;
        uint totalInterest;
        for (uint8 i; i < len; i++) {
            uint index = indexes[i];
            ItemInfo storage ii = itemInfoByIndex[index];
            if (!ii.isCanceled && !ii.isOut && ii.startTime > 0) {
                totalBalance += ii.amount;
                totalInterest += ii.interest;
            }
        }
        return (totalBalance, totalInterest);
    }

    function getSingleEstimateTime(uint index) public view returns(uint) {
        ItemInfo storage ii = itemInfoByIndex[index];
        uint preAmount = ii.preAmount;
        if (totalStakedNet >= preAmount) {
            return 0;
        } else {
            uint left = preAmount - totalStakedNet;
            uint time = left * 60 / getMaxPerTx();
            return time;
        }
    }

    function getEstimateTime(uint[] memory indexes) public view returns(uint[] memory) {
        uint len = indexes.length;
        uint[] memory res = new uint[](len);
        for (uint8 i; i < len; i++) {
            res[i] = getSingleEstimateTime(indexes[i]);
        }
        return res;
    }
}