// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.8.0;
pragma abicoder v2;

/**
 * TODO: everybody can change everybody's car data - fix this
 * TODO: add kill switch?
 */
 
contract CarRepairContract {
    struct Part {
        string id;
        string name;
        string dateMounted;
    }
    
    struct CarRepair {
        address payable repairer;
        Part[] parts;
        uint256 price;
        bool isConfirmed;
        bool isApproved;
        bool isDone;
    }
    
    address payable wallet;
    mapping (address => CarRepair) repairs;
    
    constructor() {
        wallet = msg.sender;
    }
    
    function addNewRepair(address carAddress, Part[] memory parts, uint256 price) public payable {
        require(repairs[carAddress].repairer == address(0x0), "There is a car repair for that car!");
        require(msg.value == 1 ether, "You should send 1 ether!");
        (bool success, ) = wallet.call{value: msg.value}("");
        require(success, "Transfer failed.");
        CarRepair storage carRepair = repairs[carAddress];
        carRepair.repairer = msg.sender;
        for (uint i = 0; i < parts.length; i++) {
            carRepair.parts.push(parts[i]);
        }
        carRepair.price = price;
        carRepair.isConfirmed = false;
        carRepair.isDone = false;
        carRepair.isApproved = false;
    }
    
    function getCarRepair() public view returns(CarRepair memory){
        require(repairs[msg.sender].repairer != address(0x0), "There isn't car repair for that car!");
        return repairs[msg.sender];
    }
    
    function confirmCarRepair() public {
        require(repairs[msg.sender].repairer != address(0x0), "There isn't car repair for that car!");
        repairs[msg.sender].isConfirmed = true;
    }
    
    function carRepairDone(address carAddress) public {
        require(repairs[carAddress].repairer != address(0x0), "There isn't car repair for that car!");
        require(msg.sender == repairs[carAddress].repairer, "No permission to do that!");
        require(repairs[carAddress].isConfirmed == true, "Car should confirm the car repair first!");
        repairs[carAddress].isDone = true;
    }
    
    function approveCarRepair(Part[] memory parts) public {
        require(repairs[msg.sender].repairer != address(0x0), "There isn't car repair for that car!");
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
        if (matching_parts == parts.length) {
            repairs[msg.sender].repairer.transfer(1 ether + repairs[msg.sender].price);
        } else {
            msg.sender.transfer(1 ether + repairs[msg.sender].price);
        }
        
    }
}
contract AutoHistory {
    struct Car {
       string vin;
       uint256 kilometers;
       address owner;
       Repair[] repairs;
       Crash[] crashes;
       Part[] parts;
    }
    
    struct Repair {
        uint256 price;
        string description;
    }
    
    struct Crash {
        string dateTime;
        string description;
        // TODO: add damaged parts
    }
    
    struct Part {
        string id;
        string name;
        uint dateMounted;
        uint lastRepaired; // Will this be necessary?
    }
    
    event oldPartFound(string vin, Part part);
    
    string[] private defaultParts = [
        "engine", "brakes", "ignition", "tyres", "suspension", 
        "heat pump", "mirrors", "headlights", "headlights", "taillights"
    ]; // will be assigned to every newly added car
    
    mapping (string => Car) private cars;
    
    /**
    * Get a car's repair + crash history
    * 
    * TODO: get crash history
    */
    function getHistory(string memory vin) view public returns (Repair[] memory) {
        require(carExists(vin), "Car does not exist");
        
        return cars[vin].repairs;
    
    }
     
    function carExists(string memory vin) private view returns (bool) {
        return bytes(cars[vin].vin).length > 0;
    }
     
    function addCar(string memory vin, uint256 kilometers) public {
        require(!carExists(vin), "Car already exists");
         
        Car storage newCar = cars[vin];
        newCar.vin = vin;
        newCar.kilometers = kilometers;
        newCar.owner = msg.sender;
        
        for(uint i = 0; i < defaultParts.length; i++) {
            // TODO: how to fill id and date mounted?
            // Date mounted - for now we assume the car is new and use current date
            
            Part memory newPart;
            newPart.id = "sample id";
            newPart.name = defaultParts[i];
            newPart.dateMounted = block.timestamp;
            newPart.lastRepaired = 0; // default value - means no repairs have been made
            
            newCar.parts.push(newPart);
        }
    }
    
    function addRepair(string memory vin, uint256 price, string memory description) public {
        require(carExists(vin), "Car does not exist");
        
        cars[vin].repairs.push(Repair(price, description));
    }
    
    function addCrash(string memory vin, string memory dateTime, string memory description) public {
        require(carExists(vin), "Car does not exist");
        
        cars[vin].crashes.push(Crash(dateTime, description));
    }
     
    function setKilometers(string memory vin, uint256 kilometers) public {
        require(carExists(vin), "Car does not exist");
        
        cars[vin].kilometers = kilometers;
    }
    
    /**
     * Check if any part of a car has not been changed or repaired for a long time
     * Emit events if there is anything irregullar
     */
    function checkParts(string memory vin) public view returns (string[] memory) {
        require(carExists(vin), "Car does not exist");
        
        uint oldPartsCount = 0;
              
        for(uint i = 0; i < cars[vin].parts.length; i++) {
            // 157680000 = 5 years in seconds
            if (
                block.timestamp - cars[vin].parts[i].dateMounted > 157680000 || 
                cars[vin].parts[i].lastRepaired != 0 &&
                block.timestamp - cars[vin].parts[i].lastRepaired > 157680000
            ) {
                oldPartsCount++;
            }
        }
        
        string[] memory oldParts = new string[](oldPartsCount);
        
        for(uint i = 0; i < cars[vin].parts.length; i++) {
            // 157680000 = 5 years in seconds
            if (
                block.timestamp - cars[vin].parts[i].dateMounted > 157680000 || 
                cars[vin].parts[i].lastRepaired != 0 &&
                block.timestamp - cars[vin].parts[i].lastRepaired > 157680000
            ) {
                // if a part hasn't been repaired in 5 years
                oldParts[i] = cars[vin].parts[i].name;
                //emit oldPartFound(vin, cars[vin].parts[i]);
            }
        }
        
        return oldParts;
    }
<<<<<<< HEAD
}












=======
}
>>>>>>> 33c2084635e3a51d15dd04d955021824dae49325
