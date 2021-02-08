// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.8.0;
pragma abicoder v2;
 
library Shared {
     struct Part {
        string id;
        string name;
        uint256 lastRepairKilometers;
        uint256 kilometersToRepairAt;
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
        bool exists;
        string vin;
        uint256 kilometers;
        Shared.Part[] parts;
    }
    
    mapping (address => Car) private cars;
     
    function carExists(address adr) private view returns (bool) {
        return cars[adr].exists;
    }
    
    function setCar(uint256 kilometers, string memory vin, string[] memory partIds, string[] memory partNames) public {
        require(!carExists(msg.sender), "Car already exists");
        require(partIds.length == partNames.length, "Part ids and part names must be of equal length");
         
        Car storage newCar = cars[msg.sender];
        newCar.exists = true;
        newCar.vin = vin;
        newCar.kilometers = kilometers;
        
        for (uint i = 0; i < partIds.length; i++) {
            Shared.Part memory newPart;
            
            newPart.id = partIds[i];
            newPart.name = partNames[i];
            newPart.lastRepairKilometers = 0; // default value
            newPart.kilometersToRepairAt = 0; // default value
            
            newCar.parts.push(newPart);
        }
    }
    
    function getCar() public view returns (Car memory) {
        require(carExists(msg.sender), "Car does not exist");
        
        return cars[msg.sender];
    }
     
    function setKilometers(uint256 kilometers) public {
        require(carExists(msg.sender), "Car does not exist");
        require(kilometers > cars[msg.sender].kilometers, "New kilometers must be a higher value");
        
        cars[msg.sender].kilometers = kilometers;
    }
    
    function setPart(string memory name, string memory id, uint256 lastRepairKilometers, uint256 kilometersToRepairAt) public {
        for (uint i = 0; i < cars[msg.sender].parts.length; i++) {
            if (keccak256(abi.encodePacked(cars[msg.sender].parts[i].name)) == keccak256(abi.encodePacked(name))) {
                // The part already exists
                cars[msg.sender].parts[i].id = id;
                cars[msg.sender].parts[i].lastRepairKilometers = lastRepairKilometers;
                cars[msg.sender].parts[i].kilometersToRepairAt = kilometersToRepairAt;
                return;
            }
        }
        
        // The part does not exist
        Shared.Part memory newPart;
        
        newPart.id = id;
        newPart.name = name;
        newPart.lastRepairKilometers = lastRepairKilometers; 
        newPart.kilometersToRepairAt = kilometersToRepairAt;
        
        cars[msg.sender].parts.push(newPart);
    }
}