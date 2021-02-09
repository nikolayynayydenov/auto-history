// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.8.0;
pragma abicoder v2;
 
library Shared {
     struct Part {
        string id;
        string name;
    }
    
    struct MountedPart {
        Part part;
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
        require(repairs[msg.sender].isConfirmed == false, "Already confirmed!");
        repairs[msg.sender].isConfirmed = true;
        emit confirmCarRepairEvent(repairs[msg.sender].carService, msg.sender, repairs[msg.sender].parts, repairs[msg.sender].price);
    }
    
    event declineCarRepairEvent(address carService, address car, Shared.Part[] parts, uint256 price);
    
    function declineCarRepair() public payable {
        require(repairs[msg.sender].carService != address(0x0), "There isn't car repair for that car!");
        repairs[msg.sender].carService.transfer(repairs[msg.sender].carServiceStake);
        delete repairs[msg.sender];
        emit declineCarRepairEvent(repairs[msg.sender].carService, msg.sender, repairs[msg.sender].parts, repairs[msg.sender].price);
    }
    
    event carRepairDoneEvent(address carService, address car, Shared.Part[] parts, uint256 price);
    
    function carRepairDone(address carAddress) public {
        require(repairs[carAddress].carService != address(0x0), "There isn't car repair for that car!");
        require(msg.sender == repairs[carAddress].carService, "No permission to do that!");
        require(repairs[carAddress].isConfirmed == true, "Car should confirm the car repair first!");
        require(repairs[carAddress].isDone == false, "Already done!");
        repairs[carAddress].isDone = true;
        emit carRepairDoneEvent(msg.sender, carAddress, repairs[carAddress].parts, repairs[carAddress].price);
    }
    
    event approvedCarRepairEvent(address carService, address car, Shared.MountedPart[] mountedParts, uint256 price);
    event notApprovedCarRepairEvent(address carService, address car, Shared.Part[] parts, uint256 price);
    
    function inspectCarRepair(Shared.Part[] memory parts, uint256 kilometers) public  {
        require(repairs[msg.sender].carService != address(0x0), "There isn't car repair for that car!");
        require(repairs[msg.sender].isConfirmed == true, "Car should confirm the car repair first!");
        require(repairs[msg.sender].isDone == true, "Car repair should be done before approve it.");
        require(repairs[msg.sender].isInspected == false, "Already inspected!");
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
        if (repairs[msg.sender].isApproved) {
            Shared.MountedPart[] memory mountedParts;
            for (uint256 i = 0; i < repairs[msg.sender].parts.length; i++) {
                Shared.MountedPart memory mountedPart;
                mountedPart.part.name = repairs[msg.sender].parts[i].name;
                mountedPart.part.id = repairs[msg.sender].parts[i].id;
                mountedPart.lastRepairKilometers = kilometers;
            }
            emit approvedCarRepairEvent(repairs[msg.sender].carService, msg.sender, mountedParts, repairs[msg.sender].price);
        } else {
            emit notApprovedCarRepairEvent(repairs[msg.sender].carService, msg.sender, repairs[msg.sender].parts,repairs[msg.sender].price);
        }
        
        finishCarRepair(msg.sender);
    }
    
    event finishedSuccessfulCarRepairEvent(address carService, address car, Shared.MountedPart[] parts, uint256 price);
    event finishedUnsuccessfulCarRepairEvent(address carService, address car, Shared.Part[] parts, uint256 price);
    
    function finishCarRepair(address payable car) private {
        require(repairs[car].carService != address(0x0), "There isn't car repair for that car!");
        require(repairs[car].isConfirmed == true, "Car should confirm the car repair first!");
        require(repairs[car].isDone == true, "Car repair should be done before approve it.");
        require(repairs[car].isInspected == true, "Car repair should be inspected before finish it!");
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
        Shared.MountedPart[] mountedParts;
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
            Shared.MountedPart memory newMountedPart;
            
            newMountedPart.part.id = partIds[i];
            newMountedPart.part.name = partNames[i];
            newMountedPart.lastRepairKilometers = 0; // default value
            
            newCar.mountedParts.push(newMountedPart);
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
    
    function setPart(Shared.MountedPart memory mountedPart) public {
        for (uint i = 0; i < cars[msg.sender].mountedParts.length; i++) {
            if (keccak256(abi.encodePacked(cars[msg.sender].mountedParts[i].part.name)) == keccak256(abi.encodePacked(mountedPart.part.name))) {
                // The part already exists
                cars[msg.sender].mountedParts[i].part.id = mountedPart.part.id;
                cars[msg.sender].mountedParts[i].lastRepairKilometers = mountedPart.lastRepairKilometers;
                return;
            }
        }
        
        // The part does not exist
        Shared.MountedPart memory newMountedPart;
        
        newMountedPart.part.id = mountedPart.part.id;
        newMountedPart.part.name =  mountedPart.part.name;
        newMountedPart.lastRepairKilometers = mountedPart.lastRepairKilometers; 
        
        cars[msg.sender].mountedParts.push(newMountedPart);
    }
}