// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.8.0;
pragma abicoder v2;

/**
 * TODO: everybody can change everybody's car data - fix this
 * TODO: add kill switch?
 */
 
library Shared {
     struct Part {
        string id;
        string name;
        uint256 dateMounted;
        uint256 lastRepairKilometers;
    }
    
    struct CarRepair {
        address payable carService;
        uint256 carServiceStake;
        Part[] parts;
        uint256 price;
        bool isConfirmed;
        bool isApproved;
        bool isDone;
        bool isInspected;
    }
}


contract CarRepairContract {
    
    address payable owner;
    uint256 carServiceStake;
    mapping (address => Shared.CarRepair) repairs;
    
    
    constructor(uint256 _carServiceStake) payable {
        owner = msg.sender;
        carServiceStake = _carServiceStake;
    }
    
    modifier isOwner() {
        require(msg.sender == owner, "Caller is not owner");
        _;
    }
    
    function setCarServiceStake(uint256 _carServiceStake) public isOwner {
        carServiceStake = _carServiceStake;
    }
    
    function getCarServiceStake() public view returns(uint256) {
        return carServiceStake;
    }
    
    event addNewRepairEvent(address carService, address car, Shared.Part[] parts, uint256 price);
    
    // TODO: update repaired parts' lastRepairKilometers property
    function addNewRepair(address carAddress, Shared.Part[] memory parts, uint256 price) public payable {
        require(repairs[carAddress].carService == address(0x0), "There is a car repair for that car!");
        require(msg.value == carServiceStake, "You should send car service stake!");
        
        Shared.CarRepair storage carRepair = repairs[carAddress];
        carRepair.carService = msg.sender;
        carRepair.carServiceStake = msg.value;
        for (uint i = 0; i < parts.length; i++) {
            carRepair.parts.push(parts[i]);
        }
        carRepair.price = price;
        carRepair.isConfirmed = false;
        carRepair.isDone = false;
        carRepair.isApproved = false;
        carRepair.isInspected = false;
        emit addNewRepairEvent(msg.sender, carAddress, parts, price);
    }
    
    function getCarRepair() public view returns(Shared.CarRepair memory) {
        require(repairs[msg.sender].carService != address(0x0), "There isn't car repair for that car!");
        return repairs[msg.sender];
    }
    
     event confirmCarRepairEvent(address carService, address car, Shared.Part[] parts, uint256 price);
    
    function confirmCarRepair() public payable {
        require(repairs[msg.sender].carService != address(0x0), "There isn't car repair for that car!");
        require(repairs[msg.sender].price == msg.value, "Send right value!");
        repairs[msg.sender].isConfirmed = true;
        emit confirmCarRepairEvent(repairs[msg.sender].carService, msg.sender, repairs[msg.sender].parts, repairs[msg.sender].price);
    }
    
    event carRepairDoneEvent(address carService, address car, Shared.Part[] parts, uint256 price);
    
    function carRepairDone(address carAddress) public {
        require(repairs[carAddress].carService != address(0x0), "There isn't car repair for that car!");
        require(msg.sender == repairs[carAddress].carService, "No permission to do that!");
        require(repairs[carAddress].isConfirmed == true, "Car should confirm the car repair first!");
        repairs[carAddress].isDone = true;
        emit carRepairDoneEvent(msg.sender, carAddress, repairs[carAddress].parts, repairs[carAddress].price);
    }
    
    event approvedCarRepairEvent(address carService, address car, bool isApproved);
    
    function inspectCarRepair(Shared.Part[] memory parts) public  {
        require(repairs[msg.sender].carService != address(0x0), "There isn't car repair for that car!");
        require(repairs[msg.sender].isConfirmed == true, "Car should confirm the car repair first!");
        require(repairs[msg.sender].isDone == true, "Car repair should be done before approve it.");
        uint matching_parts = 0;
        for (uint i = 0; i < repairs[msg.sender].parts.length; i++) {
            for (uint j = 0; j < parts.length; j++) {
                if (keccak256(abi.encodePacked(repairs[msg.sender].parts[i].id)) == keccak256(abi.encodePacked(parts[j].id))) {
                    matching_parts++;
                    break;
                }
            }
        }
        repairs[msg.sender].isApproved = matching_parts == parts.length;
        repairs[msg.sender].isInspected = true;
        emit approvedCarRepairEvent(repairs[msg.sender].carService, msg.sender, repairs[msg.sender].isApproved);
        finishCarRepair(msg.sender);
    }
    
    function finishCarRepair(address payable car) private {
        require(repairs[car].carService != address(0x0), "There isn't car repair for that car!");
        require(repairs[car].isConfirmed, "Car should confirm the car repair first!");
        require(repairs[car].isDone, "Car repair should be done before approve it.");
        require(repairs[car].isInspected, "Car repair should be inspected before finish it!");
        if (repairs[car].isApproved) {
            repairs[car].carService.transfer(repairs[car].carServiceStake + repairs[car].price);
        } else {
            car.transfer(repairs[car].price);
        }
        delete repairs[car];
    }
}

contract AutoHistory {
    struct Car {
        bool exists; // used to check whether the car exists
        uint256 kilometers;
        Shared.CarRepair[] repairs;
        Crash[] crashes;
        Shared.Part[] parts;
    }
    
    struct Crash {
        string dateTime;
        string description;
        // TODO: add damaged parts
    }
    
    //event oldPartFound(address adr, Shared.Part part);
    
    string[] private defaultParts = [
        "engine", "brakes", "ignition", "tyres", "suspension", 
        "heat pump", "mirrors", "headlights", "headlights", "taillights"
    ]; // will be assigned to every newly added car
    
    mapping (address => Car) private cars;
    
    /**
    * Get a car's repair + crash history
    * 
    * TODO: get crash history
    */
    function getHistory() view public returns (Shared.CarRepair[] memory, Crash[] memory) {
        require(carExists(msg.sender), "Car does not exist");
        
        return (cars[msg.sender].repairs, cars[msg.sender].crashes);
    
    }
     
    function carExists(address adr) private view returns (bool) {
        return cars[adr].exists;
    }
     
    function addCar(uint256 kilometers) public {
        require(!carExists(msg.sender), "Car already exists");
         
        Car storage newCar = cars[msg.sender];
        newCar.exists = true;
        newCar.kilometers = kilometers;
        
        for(uint i = 0; i < defaultParts.length; i++) {
            // TODO: how to fill id and date mounted?
            // Date mounted - for now we assume the car is new and use current date
            
            Shared.Part memory newPart;
            newPart.id = "sample id";
            newPart.name = defaultParts[i];
            newPart.dateMounted = block.timestamp;
            newPart.lastRepairKilometers = 0; // default value - means no repairs have been made
            
            newCar.parts.push(newPart);
        }
    }
    
    function addCrash(string memory dateTime, string memory description) public {
        require(carExists(msg.sender), "Car does not exist");
        
        cars[msg.sender].crashes.push(Crash(dateTime, description));
    }
     
    function setKilometers(uint256 kilometers) public {
        require(carExists(msg.sender), "Car does not exist");
        
        cars[msg.sender].kilometers = kilometers;
    }
    
    /**
     * Check if any part of a car has not been changed or repaired for a long time
     * Emit events if there is anything irregullar
     */
    function checkParts() public view returns (string[] memory) {
        require(carExists(msg.sender), "Car does not exist");
        
        uint oldPartsCount = 0;
              
        for(uint i = 0; i < cars[msg.sender].parts.length; i++) {
            if (
                cars[msg.sender].kilometers - cars[msg.sender].parts[i].lastRepairKilometers > 50000 || 
                cars[msg.sender].parts[i].lastRepairKilometers != 0 &&
                cars[msg.sender].kilometers - cars[msg.sender].parts[i].lastRepairKilometers > 50000
            ) {
                oldPartsCount++;
            }
        }
        
        string[] memory oldParts = new string[](oldPartsCount);
        
        for(uint i = 0; i < cars[msg.sender].parts.length; i++) {
            if (
                cars[msg.sender].kilometers - cars[msg.sender].parts[i].lastRepairKilometers > 50000 || 
                cars[msg.sender].parts[i].lastRepairKilometers != 0 &&
                cars[msg.sender].kilometers - cars[msg.sender].parts[i].lastRepairKilometers > 50000
            ) {
                oldParts[i] = cars[msg.sender].parts[i].name;
                //emit oldPartFound(msg.sender, cars[vin].parts[i]);
            }
        }
        
        return oldParts;
    }
}