// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./interfaces/IERC20.sol";
import "./interfaces/MerkleProof.sol";
import "./interfaces/IMerkleExchanger.sol";

contract MerkleExchanger is IMerkleExchanger {
    address public immutable override token;
    bytes32 public immutable override merkleRoot;
    address public immutable override oldToken;

    address private immutable holdingAccount;

    // This is a packed array of booleans.
    mapping(uint256 => uint256) private claimedBitMap;

    constructor(address token_, bytes32 merkleRoot_, address oldToken_, address holdingAccount_) {
        token = token_;
        merkleRoot = merkleRoot_;
        oldToken = oldToken_;
        holdingAccount = holdingAccount_;
    }

    function isClaimed(uint256 index) public view override returns (bool) {
        uint256 claimedWordIndex = index / 256;
        uint256 claimedBitIndex = index % 256;
        uint256 claimedWord = claimedBitMap[claimedWordIndex];
        uint256 mask = (1 << claimedBitIndex);
        return claimedWord & mask == mask;
    }

    function _setClaimed(uint256 index) private {
        uint256 claimedWordIndex = index / 256;
        uint256 claimedBitIndex = index % 256;
        claimedBitMap[claimedWordIndex] = claimedBitMap[claimedWordIndex] | (1 << claimedBitIndex);
    }

    function claim(uint256 index, address account, uint256 amount, bytes32[] calldata merkleProof) external override {
        require(!isClaimed(index), "MerkleExchanger: Drop already claimed.");

        // Verify the merkle proof.
        bytes32 node = keccak256(abi.encodePacked(index, account, amount));
        require(MerkleProof.verify(merkleProof, merkleRoot, node), "MerkleExchanger: Invalid proof.");

        // Verify the account holds the required number of old tokens and has approved their use.
        uint256 allowance = IERC20(oldToken).allowance(account, address(this));
        
        require(allowance >= amount, "MerkleExchanger: Token allowance too small.");

        require(IERC20(oldToken).balanceOf(account) >= amount, "MerkleExchanger: Account does not hold enough tokens.");

        // Mark it claimed and exchange the tokens.
        _setClaimed(index);

        uint256 oldTokenBalance = IERC20(oldToken).balanceOf(account);

        if (oldTokenBalance > amount) {
            require(IERC20(oldToken).transferFrom(account, holdingAccount, amount), "MerkleExchanger: Transfer of old tokens failed.");
            require(IERC20(token).transfer(account, amount), "MerkleExchanger: Transfer of new tokens failed.");
            emit Claimed(index, account, amount);
        } else {
            require(IERC20(oldToken).transferFrom(account, holdingAccount, oldTokenBalance), "MerkleExchanger: Transfer of old tokens failed.");
            require(IERC20(token).transfer(account, oldTokenBalance), "MerkleExchanger: Transfer of new tokens failed.");
            emit Claimed(index, account, oldTokenBalance);
        }
    }

    function withdrawOld() public {
      require(IERC20(oldToken).transfer(holdingAccount, IERC20(oldToken).balanceOf(address(this))), "MerkleExchanger::withdrawOld: Withdraw failed.");
    }
}
