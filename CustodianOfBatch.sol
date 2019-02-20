pragma solidity ^0.5.2;

import "./batch721.sol";
import "./custodian.sol";
import "./clonefactory.sol";

contract CustodianOfBatch is Custodian, CloneFactory {
    BatchNFT public batchChild;

    function initialize(BatchNFT nftLibrary, uint256 count) public {
        BatchNFT child = BatchNFT(createClone(address(nftLibrary)));
        batchChild = child;
        child.initialize(count);
    }
    
    constructor(BatchNFT nftLibrary, uint256 count)
        public
        Custodian()
    {
        initialize(nftLibrary, count);
    }
}
