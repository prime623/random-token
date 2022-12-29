// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import "./interfaces/IRandomToken.sol";
import "./VictoryToken.sol";

import "hardhat/console.sol";

contract RandomToken is ERC721, Ownable, IRandomToken {
    uint256 public price;
    uint256 public rewardAmount;
    uint256 public upgradePrice;

    uint64 public battleCount;
    uint32 public currentSupply;
    uint32 public maxSupply;

    VictoryToken public victoryToken;

    mapping(uint256 => address) public battleWinner;
    mapping(uint256 => Champion) public tokenIdToChampion;

    // Champion[] public champions;
    // mapping(uint256 => User) public tokenIdToUser;
    // mapping(address => Champion[]) public userOwnedChampions;

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _price,
        uint32 _maxSupply,
        uint256 _rewardAmount,
        VictoryToken _victoryToken
    ) ERC721(_name, _symbol) {
        price = _price;
        maxSupply = _maxSupply;
        rewardAmount = _rewardAmount;

        victoryToken = _victoryToken;
    }

    function mint() external payable {
        if (msg.value < price) revert Underpriced();
        if (currentSupply + 1 > maxSupply) revert MaxSupplyReached();

        Champion memory newChampion = _createRandomChampion(++currentSupply);
        tokenIdToChampion[currentSupply] = newChampion;

        _mint(msg.sender, currentSupply);

        // userOwnedChampions[msg.sender].push(newChampion);

        // tokenIdToUser[sender] = User({
        //     owner: sender,
        //     username: _username,
        //     id: currentSupply
        // });
    }

    function attack(uint256 _myChampion, uint256 _enemyChampion) external {
        if (
            ownerOf(_myChampion) != msg.sender &&
            ownerOf(_enemyChampion) == msg.sender
        ) revert Unauthorized();

        if (
            tokenIdToChampion[_enemyChampion].defensePower <
            tokenIdToChampion[_myChampion].attackPower
        ) {
            address attacker = msg.sender;
            battleWinner[++battleCount] = attacker;

            victoryToken.mint(attacker, rewardAmount);
        } else {
            address defender = ownerOf(_enemyChampion);
            battleWinner[++battleCount] = defender;

            victoryToken.mint(defender, rewardAmount);
        }
    }

    function upgradeChampion(
        uint256 _myChampion,
        bool attackPowerIncrease,
        bool defensePowerIncrease
    ) external payable {
        if (_ownerOf(_myChampion) == address(0)) revert TokenDoesNotExist();
        if (!attackPowerIncrease && !defensePowerIncrease)
            revert NoStatsToIncrease();

        if (attackPowerIncrease && defensePowerIncrease) {
            if (msg.value < 2 * upgradePrice)
                revert ValueSentIsTooLow(msg.value);
        } else {
            if (msg.value < upgradePrice) revert ValueSentIsTooLow(msg.value);
        }

        if (attackPowerIncrease) {
            tokenIdToChampion[_myChampion].attackPower += 10;
        }
        if (defensePowerIncrease) {
            tokenIdToChampion[_myChampion].defensePower += 10;
        }

        emit ChampionUpgraded(
            _myChampion,
            attackPowerIncrease,
            defensePowerIncrease
        );
    }

    function setUpgradePrice(uint256 _upgradePrice) external onlyOwner {
        upgradePrice = _upgradePrice;
    }

    function _createRandomChampion(
        uint256 _tokenId
    ) private view returns (Champion memory champion) {
        uint128 randomAtk = uint128(
            uint256(keccak256(abi.encodePacked(_tokenId, block.timestamp))) %
                maxSupply
        );

        uint128 randomDef = uint128(
            uint256(keccak256(abi.encodePacked(_tokenId, block.number))) %
                maxSupply
        );

        return Champion({attackPower: randomAtk, defensePower: randomDef});
    }
}
