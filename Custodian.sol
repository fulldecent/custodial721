pragma solidity ^0.5.2;

import "https://github.com/0xcert/ethereum-erc721/src/contracts/tokens/erc721.sol";
import "https://github.com/0xcert/ethereum-erc721/src/contracts/tokens/erc721-enumerable.sol";
import "https://github.com/0xcert/ethereum-erc721/src/contracts/tokens/erc721-token-receiver.sol";
import "https://github.com/0xcert/ethereum-erc721/src/contracts/utils/supports-interface.sol";
import "https://github.com/0xcert/ethereum-erc721/src/contracts/math/safe-math.sol";
import "https://github.com/0xcert/ethereum-erc721/src/contracts/utils/address-utils.sol";

interface Singleton721 /* is ERC721, ERC165 */ {
    // This works as a ERC-721 implementation but we also specify that totalSupply is always 1
    // The ownership of token #0 signifies the ownership of this contract
}

interface CustodianOf721s /* is ERC721TokenReceiver */ {
    function enter721TransferFrom(ERC721 targetContract, uint256 targetTokenId) external;
    function enter721SafeTransferFrom(ERC721 targetContract, uint256 targetTokenId) external;
    function exit721TransferFrom(ERC721 targetContract, uint256 targetTokenId) external;
    function exit721SafeTransferFrom(ERC721 targetContract, uint256 targetTokenId) external;
}

contract Custodian is Singleton721, CustodianOf721s ,/*inherited*/ ERC721, ERC165, ERC721TokenReceiver {
    using AddressUtils for address;

    address internal owner = address(0);

    function initialize() public {
        require(owner == address(0), "Already initialized");
        owner = msg.sender;
        supportedInterfaces[0x01ffc9a7] = true; // ERC165
        supportedInterfaces[0x80ac58cd] = true; // ERC721
        supportedInterfaces[0xf1f1f1f1] = true; // TODO: Finalize custodian interface
    }
    
    constructor() public {
        initialize();
    }

    // IMPLEMENT ERC165 ////////////////////////////////////////////////////////
    /**
     * @dev Mapping of supported intefraces.
     * @notice You must not set element 0xffffffff to true.
     */
    mapping(bytes4 => bool) internal supportedInterfaces;

    /**
     * @dev Function to check which interfaces are suported by this contract.
     * @param _interfaceID Id of the interface.
     * @return True if _interfaceID is supported, false otherwise.
     */
    function supportsInterface(bytes4 _interfaceID)
        external
        view
        returns (bool)
    {
        return supportedInterfaces[_interfaceID];
    }

    // IMPLEMENT ERC721 ////////////////////////////////////////////////////////
    bytes4 internal constant MAGIC_ON_ERC721_RECEIVED = 0x150b7a02;

    /**
     * @dev An address that is the approved address for token #0
     */
    address private approvedAddress;

    /**
     * @dev Mapping from owner address to mapping of operator addresses.
     * Only one owner address is active at a time because there is only one owner.
     */
    mapping (address => mapping (address => bool)) internal ownerToOperators;

    /**
     * @dev Emits when ownership of any NFT changes by any mechanism. This event emits when NFTs are
     * created (`from` == 0) and destroyed (`to` == 0). Exception: during contract creation, any
     * number of NFTs may be created and assigned without emitting Transfer. At the time of any
     * transfer, the approved address for that NFT (if any) is reset to none.
     * @param _from Sender of NFT (if address is zero address it indicates token creation).
     * @param _to Receiver of NFT (if address is zero address it indicates token destruction).
     * @param _tokenId The NFT that got transfered.
     */
    event Transfer(
        address indexed _from,
        address indexed _to,
        uint256 indexed _tokenId
    );
  
    /**
     * @dev This emits when the approved address for an NFT is changed or reaffirmed. The zero
     * address indicates there is no approved address. When a Transfer event emits, this also
     * indicates that the approved address for that NFT (if any) is reset to none.
     * @param _owner Owner of NFT.
     * @param _approved Address that we are approving.
     * @param _tokenId NFT which we are approving.
     */
    event Approval(
        address indexed _owner,
        address indexed _approved,
        uint256 indexed _tokenId
    );
  
    /**
     * @dev This emits when an operator is enabled or disabled for an owner. The operator can manage
     * all NFTs of the owner.
     * @param _owner Owner of NFT.
     * @param _operator Address to which we are setting operator rights.
     * @param _approved Status of operator rights(true if operator rights are given and false if
     * revoked).
     */
    event ApprovalForAll(
        address indexed _owner,
        address indexed _operator,
        bool _approved
    );

    /**
     * @dev Guarantees that the msg.sender is an owner or operator of the given NFT.
     * @param _tokenId ID of the NFT to validate.
     */
    modifier canOperate(
        uint256 _tokenId
    ) 
    {
        require (_tokenId == 0);
        require (owner == msg.sender || ownerToOperators[owner][msg.sender]);
        _;
    }
  
    /**
     * @dev Guarantees that the msg.sender is allowed to transfer NFT.
     * @param _tokenId ID of the NFT to transfer.
     */
    modifier canTransfer(
        uint256 _tokenId
    ) 
    {
        require (_tokenId == 0);
        require (
            owner == msg.sender
            || approvedAddress == msg.sender
            || ownerToOperators[owner][msg.sender]);
        _;
    }
  
    /**
     * @dev Guarantees that _tokenId is a valid Token.
     * @param _tokenId ID of the NFT to validate.
     */
    modifier validNFToken(
        uint256 _tokenId
    )
    {
        require (_tokenId == 0);
        _;
    }
    
    /**
     * @dev Transfers the ownership of an NFT from one address to another address. This function can
     * be changed to payable.
     * @notice Throws unless `msg.sender` is the current owner, an authorized operator, or the
     * approved address for this NFT. Throws if `_from` is not the current owner. Throws if `_to` is
     * the zero address. Throws if `_tokenId` is not a valid NFT. When transfer is complete, this
     * function checks if `_to` is a smart contract (code size > 0). If so, it calls 
     * `onERC721Received` on `_to` and throws if the return value is not 
     * `bytes4(keccak256("onERC721Received(address,uint256,bytes)"))`.
     * @param _from The current owner of the NFT.
     * @param _to The new owner.
     * @param _tokenId The NFT to transfer.
     * @param _data Additional data with no specified format, sent in call to `_to`.
     */
    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _tokenId,
        bytes calldata _data
    )
        external
    {
        _safeTransferFrom(_from, _to, _tokenId, _data);
    }
  
    /**
     * @dev Transfers the ownership of an NFT from one address to another address. This function can
     * be changed to payable.
     * @notice This works identically to the other function with an extra data parameter, except this
     * function just sets data to ""
     * @param _from The current owner of the NFT.
     * @param _to The new owner.
     * @param _tokenId The NFT to transfer.
     */
    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _tokenId
    )
        external
    {
        _safeTransferFrom(_from, _to, _tokenId, "");
    }

    /**
     * @dev Throws unless `msg.sender` is the current owner, an authorized operator, or the approved
     * address for this NFT. Throws if `_from` is not the current owner. Throws if `_to` is the zero
     * address. Throws if `_tokenId` is not a valid NFT. This function can be changed to payable.
     * @notice The caller is responsible to confirm that `_to` is capable of receiving NFTs or else
     * they maybe be permanently lost.
     * @param _from The current owner of the NFT.
     * @param _to The new owner.
     * @param _tokenId The NFT to transfer.
     */
    function transferFrom(
        address _from,
        address _to,
        uint256 _tokenId
    )
        external
        canTransfer(_tokenId)
        validNFToken(_tokenId)
    {
        require(owner == _from);
        require(_to != address(0));
        _transfer(_to, _tokenId);
    }    
    
    /**
     * @dev Set or reaffirm the approved address for an NFT. This function can be changed to payable.
     * @notice The zero address indicates there is no approved address. Throws unless `msg.sender` is
     * the current NFT owner, or an authorized operator of the current owner.
     * @param _approved Address to be approved for the given NFT ID.
     * @param _tokenId ID of the token to be approved.
     */
    function approve(
        address _approved,
        uint256 _tokenId
    )
        external
        canOperate(_tokenId)
        validNFToken(_tokenId)
    {
        require(_approved != owner);
        approvedAddress = _approved;
        emit Approval(owner, _approved, _tokenId);
    }
  
    /**
     * @dev Enables or disables approval for a third party ("operator") to manage all of
     * `msg.sender`'s assets. It also emits the ApprovalForAll event.
     * @notice This works even if sender doesn't own any tokens at the time.
     * @param _operator Address to add to the set of authorized operators.
     * @param _approved True if the operators is approved, false to revoke approval.
     */
    function setApprovalForAll(
        address _operator,
        bool _approved
    )
        external
    {
        ownerToOperators[msg.sender][_operator] = _approved;
        emit ApprovalForAll(msg.sender, _operator, _approved);
    }
  
    /**
     * @dev Returns the number of NFTs owned by `_owner`. NFTs assigned to the zero address are
     * considered invalid, and this function throws for queries about the zero address.
     * @param _owner Address for whom to query the balance.
     * @return Balance of _owner.
     */
    function balanceOf(
        address _owner
    )
        external
        view
        returns (uint256)
    {
        require(_owner != address(0));
        return _owner == owner ? 1 : 0;
    }
  
    /**
     * @dev Returns the address of the owner of the NFT. NFTs assigned to zero address are considered
     * invalid, and queries about them do throw.
     * @param _tokenId The identifier for an NFT.
     * @return Address of _tokenId owner.
     */
    function ownerOf(
        uint256 _tokenId
    )
        external
        view
        returns (address _owner)
    {
        require(_tokenId == 0);
        return owner;
    }
    

    /**
     * @dev Get the approved address for a single NFT.
     * @notice Throws if `_tokenId` is not a valid NFT.
     * @param _tokenId ID of the NFT to query the approval of.
     * @return Address that _tokenId is approved for. 
     */
    function getApproved(
        uint256 _tokenId
    )
        external
        view
        validNFToken(_tokenId)
        returns (address)
    {
        return approvedAddress;
    }
  
    /**
     * @dev Checks if `_operator` is an approved operator for `_owner`.
     * @param _owner The address that owns the NFTs.
     * @param _operator The address that acts on behalf of the owner.
     * @return True if approved for all, false otherwise.
     */
    function isApprovedForAll(
        address _owner,
        address _operator
    )
        external
        view
        returns (bool)
    {
        return ownerToOperators[_owner][_operator];
    }
    
    /**
     * @dev Actually preforms the transfer.
     * @notice Does NO checks.
     * @param _to Address of a new owner.
     * @param _tokenId The NFT that is being transferred.
     */
    function _transfer(
        address _to,
        uint256 _tokenId
    )
        internal
    {
        address from = owner;
        if (approvedAddress != address(0)) {
            approvedAddress = address(0);
        }
        owner = _to;
        emit Transfer(from, _to, _tokenId);
    }
    
    /**
     * @dev Actually perform the safeTransferFrom.
     * @param _from The current owner of the NFT.
     * @param _to The new owner.
     * @param _tokenId The NFT to transfer.
     * @param _data Additional data with no specified format, sent in call to `_to`.
     */
    function _safeTransferFrom(
        address _from,
        address _to,
        uint256 _tokenId,
        bytes memory _data
    )
        private
        canTransfer(_tokenId)
        validNFToken(_tokenId)
    {
        require(owner == _from);
        require(_to != address(0));
        _transfer(_to, _tokenId);
    
        if (_to.isContract()) {
            bytes4 retval = ERC721TokenReceiver(_to).onERC721Received(msg.sender, _from, _tokenId, _data);
            require(retval == MAGIC_ON_ERC721_RECEIVED);
        }
    }

    // IMPLEMENT CustodianOf721s ///////////////////////////////////////////////
    function enter721TransferFrom(ERC721 targetContract, uint256 targetTokenId) external {
        require(msg.sender == owner);
        address from = targetContract.ownerOf(targetTokenId);
        targetContract.transferFrom(from, address(this), targetTokenId);
    }
    
    function enter721SafeTransferFrom(ERC721 targetContract, uint256 targetTokenId) external {
        require(msg.sender == owner);
        address from = targetContract.ownerOf(targetTokenId);
        targetContract.transferFrom(from, address(this), targetTokenId);
    }
    
    // Warning: you can not take out assets that have not been put in
    function exit721TransferFrom(ERC721 targetContract, uint256 targetTokenId) external {
        require(msg.sender == owner);
        address from = targetContract.ownerOf(targetTokenId);
        targetContract.transferFrom(from, msg.sender, targetTokenId);
    }
    
    function exit721SafeTransferFrom(ERC721 targetContract, uint256 targetTokenId) external {
        require(msg.sender == owner);
        address from = targetContract.ownerOf(targetTokenId);
        targetContract.safeTransferFrom(from, msg.sender, targetTokenId);
    }
    
    // IMPLEMENT ERC721ERC721TokenReceiver /////////////////////////////////////
    /**
     * @dev Handle the receipt of a NFT. The ERC721 smart contract calls this function on the
     * recipient after a `transfer`. This function MAY throw to revert and reject the transfer. Return
     * of other than the magic value MUST result in the transaction being reverted.
     * Returns `bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))` unless throwing.
     * @return Returns `bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))`.
    */
    function onERC721Received (
        address,
        address,
        uint256,
        bytes calldata
    )
        external
        returns(bytes4)
    {
        return MAGIC_ON_ERC721_RECEIVED;
    }
}
