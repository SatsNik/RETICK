/**
 *Submitted for verification at Etherscan.io on 2024-09-10
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract TicketReselling {
    address public organizer;
    address public Archie;

    constructor(address _Archie){
        Archie=_Archie; //developers address
    }

    struct Ticket {
        address owner;
        bool forSale;
        uint resalePrice;
    }

    struct Event {
        string eventName;
        uint ticketPrice;
        uint maxResellPrice;
        uint totalTickets;
        uint ticketsSold;
        uint eventTime;
    }

    mapping(uint=>mapping(uint => Ticket)) public tickets; // Mapping of ticket IDs to Ticket structs
    mapping(uint=>Event) public events;

    event TicketPurchased(address indexed buyer,uint indexed eventId, uint indexed ticketId);
    event TicketListedForResale(string eventName, uint indexed ticketId, uint resalePrice);
    event TicketResold(address indexed seller, address indexed buyer,string eventName, uint indexed ticketId, uint price);

    function createEvent(uint _eventId, uint _totalTickets, string memory _eventName, uint _ticketPrice, uint _eventTime) external {
        require(events[_eventId].eventTime == 0, "Event already exists");
        organizer = msg.sender; // Assuming the organizer is the one creating the event
        events[_eventId] = Event({
            maxResellPrice:_ticketPrice + (_ticketPrice*30)/100,
            eventName: _eventName,
            ticketPrice: _ticketPrice,
            totalTickets: _totalTickets,
            ticketsSold: 0,
            eventTime: _eventTime
        });
    }

   modifier onlyOwner(uint _eventId, uint _ticketId) {
        require(tickets[_eventId][_ticketId].owner == msg.sender, "Not the ticket owner");
        _;
    }

    modifier isAvailableForSale(uint _eventId, uint _ticketId) {
        require(tickets[_eventId][_ticketId].forSale, "Ticket not for sale");
        _;
    }

    modifier eventNotStarted(uint _eventId) {
        require(block.timestamp < events[_eventId].eventTime - 30 minutes, "Event starts in less than 30 minutes");
        _;
    }

    function buyTicket(uint _eventId, uint _ticketId) external payable eventNotStarted(_eventId) {
        Event memory currentEvent = events[_eventId];
        require(currentEvent.ticketsSold < currentEvent.totalTickets, "Tickets are sold out");
        require(tickets[_eventId][_ticketId].owner == address(0), "This ticket is already sold");
        require(msg.value == currentEvent.ticketPrice, "Incorrect ticket price");

        tickets[_eventId][_ticketId] = Ticket(msg.sender, false, 0); // Assign the buyer as the new owner
        events[_eventId].ticketsSold++; // Increment ticketsSold for the event

        uint commissionFromOrganizer=(msg.value*10)/100;
        uint OrganizerAmount=msg.value-commissionFromOrganizer;
        payable(organizer).transfer(OrganizerAmount);
        payable(Archie).transfer(commissionFromOrganizer);
        emit TicketPurchased(msg.sender, _eventId, _ticketId);
    }

    function listTicketForResale(uint _eventId, uint _ticketId, uint _resalePrice) external onlyOwner(_eventId, _ticketId) eventNotStarted(_eventId) {
        require(_resalePrice > 0, "Resale price must be greater than 0");
        require(_resalePrice<=events[_eventId].maxResellPrice, "Your Resell Price is exceeding limit");
        tickets[_eventId][_ticketId].forSale = true;
        tickets[_eventId][_ticketId].resalePrice = _resalePrice;

        emit TicketListedForResale(events[_eventId].eventName, _ticketId, _resalePrice);
    }

    function buyResaleTicket(uint _eventId, uint _ticketId) external payable isAvailableForSale(_eventId, _ticketId) eventNotStarted(_eventId) {
        uint price=tickets[_eventId][_ticketId].resalePrice;
        require(msg.value == price, "Incorrect value sent");
        uint commission = (price * 10) / 100; // Calculate 10% commission
        uint amountToPreviousOwner = price - commission; // Amount to transfer to the previous owner

        address previousOwner = tickets[_eventId][_ticketId].owner;
        tickets[_eventId][_ticketId].owner = msg.sender;
        tickets[_eventId][_ticketId].forSale = false; // Remove the ticket from sale
        tickets[_eventId][_ticketId].resalePrice = 0;

        payable(previousOwner).transfer(amountToPreviousOwner); // Transfer the amount to the previous owner
        payable(Archie).transfer(commission); // Transfer the commission to the organizer

        emit TicketResold(previousOwner, msg.sender,events[_eventId].eventName, _ticketId, msg.value);
    }

    function getTicketOwner(uint _eventId, uint _ticketId) public view returns (address) {
        return tickets[_eventId][_ticketId].owner;
    }
}