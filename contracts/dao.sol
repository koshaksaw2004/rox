// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

interface IERC20 {
    function totalSupply() external view returns (uint);
    function balanceOf(address account) external view returns (uint);
    function transfer(address recipient, uint amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint);
    function approve(address spender, uint amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint amount) external returns (bool);
}

 
contract Dao is OwnableUpgradeable {
    struct UserInfo {
        address inviter;
        uint vipLevel;
        uint score29;
        uint score30;
        uint principal;
        uint staking;
        uint dRewards;
        uint cRewards;
        uint outScore30;

        uint directReferralNum;
        mapping (uint => address) directReferralByIndex;
        mapping (address => bool) isSonExist;

        uint satisfyV3;
        uint satisfyV4;
        uint satisfyV5;
        uint satisfyV6;
        uint satisfyV7;
        bool inV3;
        bool inV4;
        bool inV5;
        bool inV6;
        bool inV7;

        uint weeklyRewards;
        uint powerRewards;
        uint monthlyRewards;
    }
    mapping (address => UserInfo) public userInfo;

    struct SonInfo {
        address addr;
        uint vipLevel;
        uint sons; 
        uint staking;
        uint minScore;
        uint score;
    }

    address public USDT;
    address public firstAddr;
    address public pool;


    uint public startTime;
    mapping(uint => uint) public totalInCurDay;
    uint public minValidAmount;

    uint public totalFomoRewards;
    uint public totalRewarded;
    uint public gradeFomoRewardsLeft;

    address[] public v7Users;

    address[40] public v3FomoUsers;
    address[20] public v4FomoUsers;
    address[10] public v5FomoUsers;
    address[5] public v6FomoUsers;
    address[2] public v7FomoUsers;
    uint public v3Num;
    uint public v4Num;
    uint public v5Num;
    uint public v6Num;
    uint public v7Num;
    uint public nextPoint;

    struct Rank {
        address user;
        uint256 amount;
    }
    mapping (address => bool) public isValidTimellyCaller;
 
    mapping (address => mapping(uint => uint)) public scoreWeekly;
    mapping (uint => uint) public fomoRewardsWeekly;

    mapping (uint => Rank[10]) public top10Weekly;
    Rank[5] public winnersWeekly;
    uint public lastOpenTimeWeekly;

    mapping (address => mapping(uint => uint)) public scoreMonthly;
    mapping (uint => uint) public fomoRewardsMonthly;
    mapping (uint => Rank[10]) public top10Monthly;
    Rank[3] public winnersMonthly;
    uint public lastOpenTimeMonthly;

    struct PowerInfo {
        uint validSons;
        uint dScore;
        uint principal;
        uint score3;
        uint score2;
    }
    mapping (address => mapping(uint => PowerInfo)) public powerInfoMonthly;
    mapping (uint => uint) public powerRewardsMonthly;
    mapping (uint => Rank[10]) public top10PowerMonthly;
    Rank[5] public winnersPowerMonthly;
    uint public lastOpenTimePower;

    struct Record {
        uint id;
        uint amount;
        uint time;
    }
    mapping (address => Record[20]) public recordsOf; 
    mapping (address => uint) public nextIndexOf;

    uint public gradeRewardsClaimedV3;
    uint public gradeRewardsClaimedV4;
    uint public gradeRewardsClaimedV5;
    uint public gradeRewardsClaimedV6;
    uint public gradeRewardsClaimedV7;

    mapping (address => mapping(uint => uint)) public incomeOf;
    mapping (address => uint) public totalIncomeOf;

    mapping (address => mapping(uint => uint)) public newScoreOf;


    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _usdt,
        address _firstAddr,
        address _owner
    ) public initializer {
        __Ownable_init(_owner);
        isValidTimellyCaller[msg.sender] = true;
        USDT = _usdt;
        firstAddr = _firstAddr;
        minValidAmount = 200 * 1e18;
    }

    function setPool(address _pool) external onlyOwner {
        pool = _pool;
    }

    function start(uint _startTime) external {
        require(msg.sender == pool);
        startTime = _startTime;
    }

    function setMinValidAmount(uint _minValidAmount) public onlyOwner {
        minValidAmount = _minValidAmount;
    }

    function setValidTimellyCaller(address account, bool flag) public onlyOwner {
        isValidTimellyCaller[account] = flag;
    }

    function inviterOf(address user) public view returns (address) {
        return userInfo[user].inviter;
    }

    function getPassedDays() public view returns (uint) {
        return (block.timestamp - startTime) / 1 days;
    }

    function getPassedWeeks() public view returns (uint) {
        return (block.timestamp - startTime) / 7 days;
    }

    function getPassedMonths() public view returns (uint) {
        return (block.timestamp - startTime) / 30 days;
    }

    function getTotalInCurDay() public view returns (uint) {
        uint d = getPassedDays();
        return totalInCurDay[d];
    }

    function isValidInviter(address inviter) public view returns (bool) {
        if (inviter == firstAddr
            || (userInfo[inviter].inviter != address(0))
        ) {
            return true;
        } else {
            return false;
        }
    }

    function bind(address inviter) external {
        require(isValidInviter(inviter));
        require(msg.sender != firstAddr);
        UserInfo storage ui = userInfo[msg.sender];
        require(ui.inviter == address(0));
        
        ui.inviter = inviter;
    }

    function stakeInBy(address user, uint usdtAmount, uint rewards) external {
        require(msg.sender == pool);
        uint curDay = getPassedDays();
        totalInCurDay[curDay] += usdtAmount;
        uint curWeek = getPassedWeeks();
        uint curMonth = getPassedMonths();

        UserInfo storage ui = userInfo[user];
        ui.principal += usdtAmount;
        ui.staking += usdtAmount;

        address inviter = ui.inviter;
        assert(inviter != address(0));
        UserInfo storage uiI = userInfo[inviter];
        if (!uiI.isSonExist[user]) {
            uiI.isSonExist[user] = true;
            uiI.directReferralNum++;
            uiI.directReferralByIndex[uiI.directReferralNum] = user;

            if (usdtAmount >= minValidAmount) {
                powerInfoMonthly[inviter][curMonth].validSons++;
            }
        }

        if (uiI.principal >= minValidAmount) {
            uiI.dRewards += rewards * 5 / 15;
            IERC20(USDT).transfer(inviter, rewards * 5 / 15);
            addRecord(inviter, 1, rewards * 5 / 15);

            incomeOf[inviter][curDay] += rewards * 5 / 15;
            totalIncomeOf[inviter] += rewards * 5 / 15;
        } else {
            IERC20(USDT).transfer(firstAddr, rewards * 5 / 15);
        }

        _rewardToFomo(rewards * 10 / 15);

        address _inviter = inviter;
        for (uint8 i; i < 30; i++) {
            if (_inviter == address(0)) break;
            UserInfo storage uiOf = userInfo[_inviter];
            if (i < 29) {
                uiOf.score29 += usdtAmount;
                uiOf.score30 += usdtAmount;
            } else {
                uiOf.score30 += usdtAmount;
            }
            newScoreOf[_inviter][curDay] += usdtAmount;
            
            _inviter = uiOf.inviter;
        }

        _updateLevel(inviter);

        address __inviter = inviter;
        for (uint8 i; i < 3; i++) {
            if (__inviter == address(0)) break;
            scoreWeekly[__inviter][curWeek] += usdtAmount;
            if (userInfo[__inviter].vipLevel >= 2) {
                _updataWeeklyTop10(__inviter, scoreWeekly[__inviter][curWeek]);
            }

            scoreMonthly[__inviter][curMonth] += usdtAmount;
            if (userInfo[__inviter].vipLevel >= 3) {
                _updataMonthlyTop10(__inviter, scoreMonthly[__inviter][curMonth]);
            }

            __inviter = userInfo[__inviter].inviter;
        }

        powerInfoMonthly[user][curMonth].principal += usdtAmount;
        powerInfoMonthly[inviter][curMonth].dScore += usdtAmount;
        address inviter_ = inviter;
        for (uint8 i; i < 3; i++) {
            if (inviter_ == address(0)) break;

            if (i < 2) {
                powerInfoMonthly[inviter_][curMonth].score2 += usdtAmount;
                powerInfoMonthly[inviter_][curMonth].score3 += usdtAmount;
            } else {
                powerInfoMonthly[inviter_][curMonth].score3 += usdtAmount;
            }
            
            inviter_ = userInfo[inviter_].inviter;
        }

        if (ui.vipLevel >= 3) {
            _updatePowerTop10(user, getPower(user));
        }
        address inviter__ = inviter;
        for (uint8 i; i < 3; i++) {
            if (inviter__ == address(0)) break;
            if (userInfo[inviter__].vipLevel >= 3) {
                _updatePowerTop10(inviter__, getPower(inviter__));
            }
            inviter__ = userInfo[inviter__].inviter;
        }
    }

    function claimBy(address user, uint principal, uint actualProfit, uint rewards) external {
        require(msg.sender == pool);
        addRecord(user, 3, principal);
        addRecord(user, 4, actualProfit);
        uint curDay = getPassedDays();
        incomeOf[user][curDay] += actualProfit;
        totalIncomeOf[user] += actualProfit;
        UserInfo storage ui = userInfo[user];
        ui.staking -= principal;
        address _inviter = ui.inviter;
        for (uint8 i; i < 30; i++) {
            if (_inviter == address(0)) break;
            UserInfo storage uiOf = userInfo[_inviter];
            uiOf.outScore30 += principal;
            
            _inviter = uiOf.inviter;
        }

        _processCRewards(user, rewards);
    }

    function _processCRewards(address user, uint rewards) private {
        uint spend;
        uint curDay = getPassedDays();

        uint r7Num = v7Users.length;
        if (r7Num > 0) {
            uint aveReward = rewards * 5 / 30 / r7Num;
            for (uint i; i < r7Num; i++) {
                address cur = v7Users[i];
                userInfo[cur].cRewards += aveReward;
                IERC20(USDT).transfer(cur, aveReward);
                spend += aveReward;
                addRecord(cur, 2, aveReward);
                incomeOf[cur][curDay] += aveReward;
                totalIncomeOf[cur] += aveReward;
            }
        }
        
        UserInfo storage ui = userInfo[user];
        address _inviter = ui.inviter;
        uint _prevLevel = 0;
        address[] memory rewardList = new address[](7);
        uint index;
        for (uint8 i; i < 30; i++) {
            if (_inviter == address(0))
                break;

            uint levelOf = userInfo[_inviter].vipLevel;
            if (levelOf > _prevLevel && levelOf < 7 && index < 7) {
                rewardList[index] = _inviter;
                index++;
                _prevLevel = levelOf;
            }
            _inviter = userInfo[_inviter].inviter;
        }
        if (index == 0) 
            return;

        address _firstAddr = rewardList[0];
        uint firstAddrLevel = userInfo[_firstAddr].vipLevel;
        uint firstAddrRewards;
        if (firstAddrLevel == 1) {
            firstAddrRewards = rewards * 5 / 30;
        } else if(firstAddrLevel == 2) {
            firstAddrRewards = rewards * 8 / 30;
        } else if(firstAddrLevel == 3) {
            firstAddrRewards = rewards * 11 / 30;
        } else if(firstAddrLevel == 4) {
            firstAddrRewards = rewards * 15 / 30;
        } else if(firstAddrLevel == 5) {
            firstAddrRewards = rewards * 20 / 30;
        } else if(firstAddrLevel == 6) {
            firstAddrRewards = rewards * 25 / 30;
            userInfo[_firstAddr].cRewards += firstAddrRewards;
            IERC20(USDT).transfer(_firstAddr, firstAddrRewards);
            spend += firstAddrRewards;
            addRecord(_firstAddr, 2, firstAddrRewards);
            incomeOf[_firstAddr][curDay] += firstAddrRewards;
            totalIncomeOf[_firstAddr] += firstAddrRewards;
            return;
        } 
        userInfo[_firstAddr].cRewards += firstAddrRewards;
        IERC20(USDT).transfer(_firstAddr, firstAddrRewards);
        spend += firstAddrRewards;
        addRecord(_firstAddr, 2, firstAddrRewards);
        incomeOf[_firstAddr][curDay] += firstAddrRewards;
        totalIncomeOf[_firstAddr] += firstAddrRewards;

        uint prevLevel_ = firstAddrLevel;
        for (uint i = 1; i < index; i++) {
            address temp = rewardList[i];
            uint tempRewards = 0;
            uint curLevel = userInfo[temp].vipLevel;
            if (curLevel == 2) {
                tempRewards = rewards * 3 / 30;
            } else if (curLevel == 3) {
                if (prevLevel_ == 1) {
                    tempRewards = rewards * 6 / 30;
                } else if (prevLevel_ == 2) {
                    tempRewards = rewards * 3 / 30;
                }
            } else if (curLevel == 4) {
                if (prevLevel_ == 1) {
                    tempRewards = rewards * 10 / 30;
                } else if (prevLevel_ == 2) {
                    tempRewards = rewards * 7 / 30;
                } else if (prevLevel_ == 3) {
                    tempRewards = rewards * 4 / 30;
                }
            } else if (curLevel == 5) {
                if (prevLevel_ == 1) {
                    tempRewards = rewards * 15 / 30;
                } else if (prevLevel_ == 2) {
                    tempRewards = rewards * 12 / 30;
                } else if (prevLevel_ == 3) {
                    tempRewards = rewards * 9 / 30;
                } else if (prevLevel_ == 4) {
                    tempRewards = rewards * 5 / 30;
                }
            } else if (curLevel == 6) {
                if (prevLevel_ == 1) {
                    tempRewards = rewards * 20 / 30;
                } else if (prevLevel_ == 2) {
                    tempRewards = rewards * 17 / 30;
                } else if (prevLevel_ == 3) {
                    tempRewards = rewards * 14 / 30;
                } else if (prevLevel_ == 4) {
                    tempRewards = rewards * 10 / 30;
                } else if (prevLevel_ == 5) {
                    tempRewards = rewards * 5 / 30;
                }
            }
            userInfo[temp].cRewards += tempRewards;
            IERC20(USDT).transfer(temp, tempRewards);
            spend += tempRewards;
            addRecord(temp, 2, tempRewards);
            incomeOf[temp][curDay] += tempRewards;
            totalIncomeOf[temp] += tempRewards;
            prevLevel_ = curLevel;
        }
        if (rewards > spend) {
            IERC20(USDT).transfer(firstAddr, rewards - spend);
        }
    }

    function _rewardToFomo(uint rewards) private {
        uint curDay = getPassedDays();
        totalFomoRewards += rewards;
        uint gradeReward = rewards * 30 / 100;
        uint weekReward = rewards * 20 / 100;
        uint monthReward = rewards * 30 / 100;
        uint powerReward = rewards * 20 / 100;

        gradeFomoRewardsLeft += gradeReward;
        (address to, uint nextReward, uint level) = getNextRewardArg();

        if (gradeFomoRewardsLeft >= nextReward && to != address(0)) {
            if (level == 3) {
                userInfo[to].satisfyV3 = 1;
            } else if (level == 4) {
                userInfo[to].satisfyV4 = 1;
            } else if (level == 5) {
                userInfo[to].satisfyV5 = 1;
            } else if (level == 6) {
                userInfo[to].satisfyV6 = 1;
            } else if (level == 7) {
                userInfo[to].satisfyV7 = 1;
            }
            
            gradeFomoRewardsLeft -= nextReward;
            nextPoint++;
            addRecord(to, 5, nextReward);
            incomeOf[to][curDay] += nextReward;
            totalIncomeOf[to] += nextReward;
        }
        uint curWeek = getPassedWeeks();
        uint curMonth = getPassedMonths();
        fomoRewardsWeekly[curWeek] += weekReward;
        fomoRewardsMonthly[curMonth] += monthReward;
        powerRewardsMonthly[curMonth] += powerReward;
    }

    function getNextRewardArg() public view returns (address, uint, uint) {
        uint reward;
        address to;
        uint level;
        if (nextPoint > 76) {
            reward = 0;
        } else if (nextPoint > 74) {
            reward = 40 * 1e22;
            to = v7FomoUsers[nextPoint - 75];
            level = 7;
        } else if (nextPoint > 69) {
            reward = 10 * 1e22;
            to = v6FomoUsers[nextPoint - 70];
            level = 6;
        } else if (nextPoint > 59) {
            reward = 3 * 1e22;
            to = v5FomoUsers[nextPoint - 60];
            level = 5;
        } else if (nextPoint > 39) {
            reward = 1 * 1e22;
            to = v4FomoUsers[nextPoint - 40];
            level = 4;
        } else {
            reward = 5000 * 1e18;
            to = v3FomoUsers[nextPoint];
            level = 3;
        }
        return (to, reward, level);
    } 

    function _updateLevel(address inviter) private {
        for (uint8 i; i < 30; i++) {
            if (inviter == address(0) || inviter == firstAddr) break;
            UserInfo storage uiOf = userInfo[inviter];
            uint to = _canUpgradeTo(inviter);
            if (to > 0) {
                _upgradeTo(inviter, to);
            }
            inviter = uiOf.inviter;
        }
    }

    function getMinScore(address user) public view returns (uint) {
        UserInfo storage ui = userInfo[user];
        uint sonNum = ui.directReferralNum;
        if (sonNum < 2) return 0;
        uint max = 0;
        for (uint8 i = 1; i <= sonNum; i++) {
            address cur = ui.directReferralByIndex[i];
            uint curLineScore = userInfo[cur].principal + userInfo[cur].score29;
            if (curLineScore > max) {
                max = curLineScore;
            }
        }

        return ui.score30 - max;
    }

    function _canUpgradeTo(address user) public view returns (uint) {
        uint to = 0;
        UserInfo storage ui = userInfo[user];
        uint minScore = getMinScore(user);
        if (minScore >= 1000 * 1e22) {
            if (ui.vipLevel < 7) to = 7;
        } else if (minScore >= 400 * 1e22) {
            if (ui.vipLevel < 6) to = 6;
        } else if (minScore >= 200 * 1e22) {
            if (ui.vipLevel < 5) to = 5;
        } else if (minScore >= 100 * 1e22) {
            if (ui.vipLevel < 4) to = 4;
        } else if (minScore >= 25 * 1e22) {
            if (ui.vipLevel < 3) to = 3;
        } else if (minScore >= 5 * 1e22) {
            if (ui.vipLevel < 2) to = 2;
        } else if (minScore >= 1 * 1e21) {
            if (ui.vipLevel < 1) to = 1;
        }
        return to;
    }

    function _upgradeTo(address user, uint to) private {
        UserInfo storage ui = userInfo[user];
        ui.vipLevel = to;
        if (to == 7) {
            v7Users.push(user);
        }

        if (to == 3) {
            if (v3Num < 40) {
                v3FomoUsers[v3Num] = user;
                ui.inV3 = true;
            }
            v3Num++;
        } else if (to == 4) {
            if (v4Num < 20) {
                v4FomoUsers[v4Num] = user;
                ui.inV4 = true;
            }
            v4Num++;
        } else if (to == 5) {
            if (v5Num < 10) {
                v5FomoUsers[v5Num] = user;
                ui.inV5 = true;
            }
            v5Num++;
        } else if (to == 6) {
            if (v6Num < 5) {
                v6FomoUsers[v6Num] = user;
                ui.inV6 = true;
            }
            v6Num++;
        } else if (to == 7) {
            if (v7Num < 2) {
                v7FomoUsers[v7Num] = user;
                ui.inV7 = true; 
            }
            v7Num++;
        }

        if (to >= 2) {
            uint curWeek = getPassedWeeks();
            _updataWeeklyTop10(user, scoreWeekly[user][curWeek]);
        }

        if (to >= 3) {
            uint curMonth = getPassedMonths();
            _updataMonthlyTop10(user, scoreMonthly[user][curMonth]);

            _updatePowerTop10(user, getPower(user));
        }
    }

    function _updataWeeklyTop10(address user, uint newAmount) private {
        uint curWeek = getPassedWeeks();
        int256 existingIndex = -1;
        for (uint i = 0; i < 10; i++) {
            if (top10Weekly[curWeek][i].user == user) {
                existingIndex = int256(i);
                break;
            }
        }

        if (existingIndex >= 0) {
            top10Weekly[curWeek][uint256(existingIndex)].amount = newAmount;
            _bubbleUpWeekly(uint256(existingIndex));
            return;
        }

        if (newAmount > top10Weekly[curWeek][9].amount) {
            top10Weekly[curWeek][9] = Rank(user, newAmount);
            _bubbleUpWeekly(9);
        }
    }

    function _bubbleUpWeekly(uint256 index) private {
        uint curWeek = getPassedWeeks();
        while (index > 0 && top10Weekly[curWeek][index].amount > top10Weekly[curWeek][index-1].amount) {
            Rank memory temp = top10Weekly[curWeek][index-1];
            top10Weekly[curWeek][index-1] = top10Weekly[curWeek][index];
            top10Weekly[curWeek][index] = temp;
            index--;
        }
    }

    function getTop10Weekly() public view returns (Rank[10] memory) {
        uint curWeek = getPassedWeeks();
        return top10Weekly[curWeek];
    }

    function getWinnersWeekly() public view returns (Rank[5] memory) {
        return winnersWeekly;
    }

    function timelyCallWeekly() external {
        require(isValidTimellyCaller[msg.sender]);
        require(block.timestamp >= lastOpenTimeWeekly + 7 days);
        lastOpenTimeWeekly = block.timestamp - block.timestamp / 1 hours;
        delete winnersWeekly;
        
        uint curDay = getPassedDays();
        uint curWeek = getPassedWeeks();
        uint lastWeek = curWeek - 1;

        uint totalRewards = fomoRewardsWeekly[lastWeek];
        Rank[10] memory top10LastWeek = top10Weekly[lastWeek];

        for (uint i; i < 5; i++) {
            address user = top10LastWeek[i].user;
            uint amount = 0;
            if (i == 0) {
                amount = totalRewards * 25 / 50;
            } else if (i == 1) {
                amount = totalRewards * 10 / 50;
            } else if (i == 2) {
                amount = totalRewards * 6 / 50;
            } else if (i == 3) {
                amount = totalRewards * 5 / 50;
            } else if (i == 4) {
                amount = totalRewards * 4 / 50;
            }
            
            if (user != address(0)) {
                winnersWeekly[i] = Rank(user, amount);
                userInfo[user].weeklyRewards += amount;
                addRecord(user, 7, amount);
                incomeOf[user][curDay] += amount;
                totalIncomeOf[user] += amount;
            }
        }

    }

    function claimWeeklyRewards() external {
        UserInfo storage ui = userInfo[msg.sender];
        uint amount = ui.weeklyRewards;
        ui.weeklyRewards = 0;
        require(amount > 0);
        IERC20(USDT).transfer(msg.sender, amount);

        totalRewarded += amount;
    }

    function _updataMonthlyTop10(address user, uint newAmount) private {
        uint curMonth = getPassedMonths();
        int256 existingIndex = -1;
        for (uint i = 0; i < 10; i++) {
            if (top10Monthly[curMonth][i].user == user) {
                existingIndex = int256(i);
                break;
            }
        }

        if (existingIndex >= 0) {
            top10Monthly[curMonth][uint256(existingIndex)].amount = newAmount;
            _bubbleUpMonthly(uint256(existingIndex));
            return;
        }

        if (newAmount > top10Monthly[curMonth][9].amount) {
            top10Monthly[curMonth][9] = Rank(user, newAmount);
            _bubbleUpMonthly(9);
        }
    }

    function _bubbleUpMonthly(uint256 index) private {
        uint curMonth = getPassedMonths();
        while (index > 0 && top10Monthly[curMonth][index].amount > top10Monthly[curMonth][index-1].amount) {
            Rank memory temp = top10Monthly[curMonth][index-1];
            top10Monthly[curMonth][index-1] = top10Monthly[curMonth][index];
            top10Monthly[curMonth][index] = temp;
            index--;
        }
    }

    function getTop10Monthly() public view returns (Rank[10] memory) {
        uint curMonth = getPassedMonths();
        return top10Monthly[curMonth];
    }

    function getWinnersMonthly() public view returns (Rank[3] memory) {
        return winnersMonthly;
    }

    function timelyCallMonthly() external {
        require(isValidTimellyCaller[msg.sender]);
        require(block.timestamp >= lastOpenTimeMonthly + 30 days);
        lastOpenTimeMonthly = block.timestamp - block.timestamp / 1 hours;
        delete winnersMonthly;
        
        uint curDay = getPassedDays();
        uint curMonth = getPassedMonths();
        uint lastMonth = curMonth - 1;

        uint totalRewards = fomoRewardsMonthly[lastMonth];
        Rank[10] memory top10LastMonth = top10Monthly[lastMonth];

        for (uint i; i < 3; i++) {
            address user = top10LastMonth[i].user;
            uint amount = 0;
            if (i == 0) {
                amount = totalRewards * 15 / 30;
            } else if (i == 1) {
                amount = totalRewards * 10 / 30;
            } else if (i == 2) {
                amount = totalRewards * 5 / 30;
            } 
            
            if (user != address(0)) {
                winnersMonthly[i] = Rank(user, amount);
                userInfo[user].monthlyRewards += amount;
                addRecord(user, 8, amount);
                incomeOf[user][curDay] += amount;
                totalIncomeOf[user] += amount;
            }
        }

    }

    function claimMonthlyRewards() external {
        UserInfo storage ui = userInfo[msg.sender];
        uint amount = ui.monthlyRewards;
        ui.monthlyRewards = 0;
        require(amount > 0);
        IERC20(USDT).transfer(msg.sender, amount);

        totalRewarded += amount;
    }

    function getPower(address user) public view returns (uint) {
        uint curMonth = getPassedMonths();
        UserInfo storage ui = userInfo[user];
        PowerInfo storage pi = powerInfoMonthly[user][curMonth];
        uint minScore = getMinScore3(user);
        uint power = ui.principal * pi.validSons * pi.dScore / 1e18;
        power = power * minScore / 1e26;
        return power;
    }

    function getMinScore3(address user) public view returns (uint) {
        uint curMonth = getPassedMonths();
        UserInfo storage ui = userInfo[user];
        uint sonNum = ui.directReferralNum;
        if (sonNum < 2) return 0;
        uint max = 0;
        for (uint8 i = 1; i <= sonNum; i++) {
            address cur = ui.directReferralByIndex[i];
            PowerInfo storage pi = powerInfoMonthly[cur][curMonth];
            uint curLineScore = pi.principal + pi.score2;
            if (curLineScore > max) {
                max = curLineScore;
            }
        }

        return powerInfoMonthly[user][curMonth].score3 - max;
    }

    function _updatePowerTop10(address user, uint newAmount) private {
        uint curMonth = getPassedMonths();
        int256 existingIndex = -1;
        for (uint i = 0; i < 10; i++) {
            if (top10PowerMonthly[curMonth][i].user == user) {
                existingIndex = int256(i);
                break;
            }
        }

        if (existingIndex >= 0) {
            top10PowerMonthly[curMonth][uint256(existingIndex)].amount = newAmount;
            _bubbleUpPowerMonthly(uint256(existingIndex));
            return;
        }

        if (newAmount > top10PowerMonthly[curMonth][9].amount) {
            top10PowerMonthly[curMonth][9] = Rank(user, newAmount);
            _bubbleUpPowerMonthly(9);
        }
    }

    function _bubbleUpPowerMonthly(uint256 index) private {
        uint curMonth = getPassedMonths();
        while (index > 0 && top10PowerMonthly[curMonth][index].amount > top10PowerMonthly[curMonth][index-1].amount) {
            Rank memory temp = top10PowerMonthly[curMonth][index-1];
            top10PowerMonthly[curMonth][index-1] = top10PowerMonthly[curMonth][index];
            top10PowerMonthly[curMonth][index] = temp;
            index--;
        }
    }

    function getTop10PowerMonthly() public view returns (Rank[10] memory) {
        uint curMonth = getPassedMonths();
        return top10PowerMonthly[curMonth];
    }

    function getWinnersPowerMonthly() public view returns (Rank[5] memory) {
        return winnersPowerMonthly;
    }

    function timelyCallPowerMonthly() external {
        require(isValidTimellyCaller[msg.sender]);
        require(block.timestamp >= lastOpenTimePower + 30 days);
        lastOpenTimePower = block.timestamp - block.timestamp / 1 hours;
        delete winnersPowerMonthly;
        
        uint curDay = getPassedDays();
        uint curMonth = getPassedMonths();
        uint lastMonth = curMonth - 1;

        uint totalRewards = powerRewardsMonthly[lastMonth];
        Rank[10] memory top10PowerLastMonth = top10PowerMonthly[lastMonth];

        for (uint i; i < 5; i++) {
            address user = top10PowerLastMonth[i].user;
            uint amount = 0;
            if (i == 0) {
                amount = totalRewards * 10 / 20;
            } else if (i == 1) {
                amount = totalRewards * 4 / 20;
            } else if (i == 2) {
                amount = totalRewards * 3 / 20;
            } else if (i == 3) {
                amount = totalRewards * 2 / 20;
            } else if (i == 4) {
                amount = totalRewards * 1 / 20;
            } 
            
            if (user != address(0)) {
                winnersPowerMonthly[i] = Rank(user, amount);
                userInfo[user].powerRewards += amount;
                addRecord(user, 6, amount);
                incomeOf[user][curDay] += amount;
                totalIncomeOf[user] += amount;
            }
        }
    }

    function claimPowerRewards() external {
        UserInfo storage ui = userInfo[msg.sender];
        uint amount = ui.powerRewards;
        ui.powerRewards = 0;
        require(amount > 0);
        IERC20(USDT).transfer(msg.sender, amount);
        
        totalRewarded += amount;
    }

    function addRecord(address user, uint id, uint amount) private {
        recordsOf[user][nextIndexOf[user]] = Record(id, amount, block.timestamp);
        nextIndexOf[user]++;
        if (nextIndexOf[user] >= 20) {
            nextIndexOf[user] = 0;
        }
    }

    function claimGradeRewards(uint id) external {
        require(id >= 3 && id <= 7);
        UserInfo storage ui = userInfo[msg.sender];
        uint amount;
        if (id == 3) {
            require(ui.satisfyV3 == 1);
            ui.satisfyV3 = 2;
            gradeRewardsClaimedV3++;
            amount = 5000 * 1e18;
        } else if (id == 4) {
            require(ui.satisfyV4 == 1);
            ui.satisfyV4 = 2;
            gradeRewardsClaimedV4++;
            amount = 10000 * 1e18;
        } else if (id == 5) {
            require(ui.satisfyV5 == 1);
            ui.satisfyV5 = 2;
            gradeRewardsClaimedV5++;
            amount = 30000 * 1e18;
        } else if (id == 6) {
            require(ui.satisfyV6 == 1);
            ui.satisfyV6 = 2;
            gradeRewardsClaimedV6++;
            amount = 100000 * 1e18;
        } else if (id == 7) {
            require(ui.satisfyV7 == 1);
            ui.satisfyV7 = 2;
            gradeRewardsClaimedV7++;
            amount = 340000 * 1e18;
        }
        IERC20(USDT).transfer(msg.sender, amount);
        totalRewarded += amount;
    }

    function getIncomeOf(address user) public view returns (uint total, uint today, uint yesterday) {
        total = totalIncomeOf[user];
        uint curDay = getPassedDays();
        today = incomeOf[user][curDay];
        if (curDay == 0) {
            yesterday = 0;
        } else {
            yesterday = incomeOf[user][curDay - 1];
        }
    }

    function getFomoInfo(address user) public view returns (uint week, uint month, uint power) {
       uint curWeek = getPassedWeeks();
       uint curMonth = getPassedMonths();
       
       week = scoreWeekly[user][curWeek]; 
       month = scoreMonthly[user][curMonth];
       power = getPower(user);
    }

    function getNewScoreToday(address user) public view returns (uint) {
        uint curDay = getPassedDays();
        return newScoreOf[user][curDay];
    }

    function getSons(address user) public view returns (SonInfo[] memory) {
        UserInfo storage ui = userInfo[user];
        uint len = ui.directReferralNum;
        SonInfo[] memory infos = new SonInfo[](len);
        address cur;
        for(uint i; i < len; i++) {
            cur = ui.directReferralByIndex[i+1];
            infos[i].addr = cur;
            UserInfo storage uiOf = userInfo[cur];
            infos[i].vipLevel = uiOf.vipLevel;
            infos[i].sons = uiOf.directReferralNum;
            infos[i].staking = uiOf.staking;
            infos[i].minScore = getMinScore(cur);
            infos[i].score = uiOf.score30 - uiOf.outScore30;
        }
        return infos;
    }

    function getRecords(address user) public view returns (Record[20] memory) {
        return recordsOf[user];
    }

    function getGradeFomoInfo() public view returns (uint[5] memory) {
        return [gradeRewardsClaimedV3, gradeRewardsClaimedV4, gradeRewardsClaimedV5, 
        gradeRewardsClaimedV6, gradeRewardsClaimedV7];
    }

    function getFomoRewards() public view returns (uint[4] memory) {
        uint curWeek = getPassedWeeks();
        uint curMonth = getPassedMonths();
        uint weekReward = fomoRewardsWeekly[curWeek];
        uint monthReward = fomoRewardsMonthly[curMonth];
        uint powerReward = powerRewardsMonthly[curMonth];

        return [gradeFomoRewardsLeft, weekReward, powerReward, monthReward];
    }
}