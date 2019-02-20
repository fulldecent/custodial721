pragma solidity ^0.5.2;

import "./batch721.sol";
import "./custodian.sol";

contract CustodianOfBatch is Custodian {
    BatchNFT public batchChild;

    function initialize(uint256 count) public {
        batchChild = new BatchNFT(count);    }
    
    constructor(uint256 count)
        public
        Custodian()
    {
        initialize(count);
    }
}
