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
       Repair[] repairs;
       address owner;
    }
    
    struct Repair {
        uint256 price;
        string description;
    }
    
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
    }
    // Kolio
    function addRepair(string memory vin, uint256 price, string memory description) public {
        require(carExists(vin), "Car does not exist");
        
        cars[vin].repairs.push(Repair(price, description));
    }
     
    function setKilometers(string memory vin, uint256 kilometers) public {
        require(carExists(vin), "Car does not exist");
        
        cars[vin].kilometers = kilometers;
    }
}