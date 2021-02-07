// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.8.0;
pragma abicoder v2;

/**
 * TODO: everybody can change everybody's car data - fix this
 * TODO: add kill switch?
 */
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
}