// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@pancakeswap/pancake-swap-lib/contracts/token/BEP20/SafeBEP20.sol";

contract MoonLabTimeLock is Context, Ownable {
    using SafeMath for uint256;

    using Address for address;
    using SafeBEP20 for IBEP20;

    address public constant DEV_ADDRESS_1 =
        0x60c71159B1caC428434d585DCF5B3Cf2A5B71eBF;
    address public constant DEV_ADDRESS_2 =
        0x7F4c53DBED358d5D9b8A5347Ac5fc9d159a5C2cd;
    address public constant DEV_ADDRESS_3 =
        0xe9864674a5BD7954A61feff2683D42D2fA282B8C;
    address public constant DEV_ADDRESS_4 =
        0x28f4Fdea7A9A68eAf4Ca8dA26C71436a3A719afe;
    address public constant BURN_ADDRESS =
        0x000000000000000000000000000000000000dEaD;
        
    IBEP20 public immutable MLAB;
    uint256 public constant maxFundsPerAddress = 15 * 10**21; // 1.5% per address
    uint256 public mlabPerBlock;
    uint256 public totalClaimed;
    uint256 public totalBurned;
    uint256 public blockNumberToUnlock;

    mapping(address => uint256) public claimedAmount;

    event ClaimDevFunds(
        address devAddress,
        uint256 blockNumber,
        uint256 amount
    );
    event Burned(uint256 timestamp, uint256 amount);

    mapping(address => bool) private inClaim;
    modifier lockForClaim(address devAddress) {
        inClaim[devAddress] = true;
        _;
        inClaim[devAddress] = false;
    }

    modifier onlyDev() {
        require(
            DEV_ADDRESS_1 == _msgSender() ||
                DEV_ADDRESS_2 == _msgSender() ||
                DEV_ADDRESS_3 == _msgSender() ||
                DEV_ADDRESS_4 == _msgSender(),
            "Only Dev: caller is not the developer"
        );
        _;
    }

    constructor(address mlabAddress) {
        IBEP20 token = IBEP20(mlabAddress);
        MLAB = token;
    }

    function lock(uint256 _blockNumberToUnlock, uint256 _mlabPerBlock)
        external
        onlyOwner()
    {
        require(blockNumberToUnlock == 0, "Can not lock again");
        mlabPerBlock = _mlabPerBlock;
        blockNumberToUnlock = _blockNumberToUnlock;
    }

    function capitalFunds() public view returns (uint256) {
        return MLAB.balanceOf(address(this));
    }

    function burn(uint256 amount) external onlyOwner() {
        require(amount <= capitalFunds(), "insufficient funds.");
        MLAB.safeTransfer(BURN_ADDRESS, amount);
        totalBurned = totalBurned.add(amount);
        emit Burned(block.timestamp, amount);
    }

    function availableClaim(address devAddress) public view returns (uint256) {
        return _availableClaim(devAddress);
    }

    function _availableClaim(address devAddress)
        private
        view
        returns (uint256)
    {
        uint256 diff;
        uint256 amount;
        if (
            DEV_ADDRESS_1 == devAddress ||
            DEV_ADDRESS_2 == devAddress ||
            DEV_ADDRESS_3 == devAddress ||
            DEV_ADDRESS_4 == devAddress
        ) {
            if (block.number >= blockNumberToUnlock) {
                diff = block.number.sub(blockNumberToUnlock);
            }
            if (diff.mul(mlabPerBlock) >= maxFundsPerAddress) {
                amount = maxFundsPerAddress.sub(claimedAmount[devAddress]);
            } else {
                amount = diff.mul(mlabPerBlock).sub(claimedAmount[devAddress]);
            }
        }
        return amount;
    }

    function claimDevFunds(uint256 amount) external onlyDev() {
        require(!inClaim[_msgSender()], "Are Claim");
        _claimDevFunds(amount);
    }

    function _claimDevFunds(uint256 amount) private lockForClaim(_msgSender()) {
        require(block.number >= blockNumberToUnlock, "Dev Funds are locked.");
        require(amount <= capitalFunds(), "insufficient funds.");
        require(
            _availableClaim(_msgSender()) > 0 &&
                _availableClaim(_msgSender()) >= amount,
            "The amount to be withdrawn must be less than the unlocked amount."
        );
        require(
            claimedAmount[_msgSender()].add(amount) <= maxFundsPerAddress,
            "Dev funds per address should be withdrawn not more than maxFundsPerAddress"
        );
        totalClaimed = totalClaimed.add(amount);
        claimedAmount[_msgSender()] = claimedAmount[_msgSender()].add(amount);
        MLAB.safeTransfer(_msgSender(), amount);
        emit ClaimDevFunds(_msgSender(), block.number, amount);
    }
}
