// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";


error Unauthorized(address caller);
error EventAlreadyExists(uint256 eventId);
error EventDoesNotExist(uint256 eventId);
error InvalidEventId(uint256 eventId);
error URIEmpty();
error MintLimitExceeded(address creator);
error NotAuthorizedToMint(uint256 eventId, address caller);
error NotAuthorizedToBurn(uint256 eventId, address caller);

contract TicketingSystem is ERC1155, AccessControl, ERC1155Burnable, ERC1155Supply {
    // bytes32 public constant override DEFAULT_ADMIN_ROLE = keccak256("DEFAULT_ADMIN_ROLE");
    bytes32 public constant EVENT_CREATOR_ROLE = keccak256("EVENT_CREATOR_ROLE");

    uint256 private _nextEventId = 1; // Start IDs from 1

    struct Event {
        string name;
        string place;
        string organizerName;
        uint256 date; // Timestamp for the event date
        address eventCreator; // Address of the event creator
    }

    // Mapping to store URIs for each token (event ID)
    mapping(uint256 => string) private _tokenURIs;
    mapping(uint256 => Event) private _events;
    mapping(uint256 => address) public eventManagers;
    mapping(address => bool) private hasMinted; // Track if event creator has minted 1 event

    constructor(address defaultAdmin) ERC1155("") {
        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
    }

    // Modifier to restrict event creators to their events
    modifier onlyEventCreator(uint256 eventId) {
        if(eventManagers[eventId] == msg.sender){
            revert Unauthorized(msg.sender);
        }
        _;
    }

    // Create an event and assign the creator as its manager
    function createEvent(
        string memory name,
        string memory place,
        string memory organizerName,
        uint256 date,
        string memory eventUri
    ) public {
        if (hasMinted[msg.sender]) {
            revert MintLimitExceeded(msg.sender);
        }

        uint256 eventId = _nextEventId++;
        if(eventManagers[eventId] == address(0)){
            revert EventAlreadyExists(eventId);
        }

        // Create the event
        _events[eventId] = Event({
            name: name,
            place: place,
            organizerName: organizerName,
            date: date,
            eventCreator: msg.sender
        });

        // Assign the event manager role to the creator
        eventManagers[eventId] = msg.sender;
        _grantRole(EVENT_CREATOR_ROLE, msg.sender);

        // Mark that this event creator has minted one event
        hasMinted[msg.sender] = true;

        // Set the event URI for this event ID
        _setTokenURI(eventId, eventUri);
    }

    function mint(address to, uint256 id, uint256 amount, bytes memory data)
    public
    onlyRole(EVENT_CREATOR_ROLE)
{
    // Ensure the event creator is minting for their own event
    if(eventManagers[id] == msg.sender){
        revert  NotAuthorizedToMint(id,msg.sender);
    }

    // Mint the specified amount of tickets for the given event ID
    _mint(to, id, amount, data);
}


    // Mint tickets for the creator's own event in batch
    // function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
    //     public
    //     onlyRole(EVENT_CREATOR_ROLE)
    // {
    //     for (uint i = 0; i < ids.length; i++) {
    //         require(eventManagers[ids[i]] == msg.sender, "Not authorized to mint for this event");
    //     }

    //     _mintBatch(to, ids, amounts, data);
    // }

    // Burn tickets for the creator's own event in batch
    // function burnBatch(address account, uint256[] memory ids, uint256[] memory amounts)
    //     public override
    //     onlyRole(EVENT_CREATOR_ROLE)
    // {
    //     for (uint i = 0; i < ids.length; i++) {
    //         require(eventManagers[ids[i]] == msg.sender, "Not authorized to burn for this event");
    //     }

    //     _burnBatch(account, ids, amounts);
    // }

    function burn(address account, uint256 id, uint256 amount)
    public override 
    onlyRole(EVENT_CREATOR_ROLE)
{
    // Ensure the event creator is burning tickets for their own event
    if(eventManagers[id] == msg.sender){
        revert NotAuthorizedToBurn(id,msg.sender);

    }

    // Burn the specified amount of tickets for the given event ID
    _burn(account, id, amount);
}

    // Internal function to set the URI for a specific token ID (event)
    function _setTokenURI(uint256 tokenId, string memory uri_) internal  {
        if(bytes(uri_).length > 0){
            revert URIEmpty();

        }
        _tokenURIs[tokenId] = uri_;
    }

    // Function to update the URI for a specific event (token ID)
    function updateTokenURI(uint256 tokenId, string memory newURI) public onlyEventCreator(tokenId) {
        _setTokenURI(tokenId, newURI);
    }

    // New function to update event details
  function updateEventDetails(
    uint256 eventId,
    string memory newName,
    string memory newPlace,
    string memory newOrganizerName,
    uint256 newDate
) public onlyEventCreator(eventId) {
    if(eventId > 0 && eventId < _nextEventId){
        revert EventDoesNotExist(eventId);
    }

    Event storage eventDetails = _events[eventId];

    eventDetails.name = newName;
    eventDetails.place = newPlace;
    eventDetails.organizerName = newOrganizerName;
    eventDetails.date = newDate;
}


    // Override the uri function to return the unique URI for each event (token ID)
    function uri(uint256 tokenId) public view override returns (string memory) {
        string memory tokenURI = _tokenURIs[tokenId];
       if (bytes(tokenURI).length == 0) {
            revert EventDoesNotExist(tokenId);
        }
        return tokenURI;
    }

    // Retrieve event details
    function getEvent(uint256 eventId)
        public
        view
        returns (string memory name, string memory place, string memory organizerName, uint256 date, string memory eventUri)
    {
        if (eventId <= 0 || eventId >= _nextEventId) {
            revert InvalidEventId(eventId);
        }
        Event storage eventDetails = _events[eventId];
        return (eventDetails.name, eventDetails.place, eventDetails.organizerName, eventDetails.date, _tokenURIs[eventId]);
    }

    // Override the necessary functions for batch operations and total supply tracking
    function _update(address from, address to, uint256[] memory ids, uint256[] memory values)
        internal
        override(ERC1155, ERC1155Supply)
    {
        super._update(from, to, ids, values);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
