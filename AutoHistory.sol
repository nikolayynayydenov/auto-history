// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.8.0;

/**
 *  TODO: everybody can change everybody's car data - fix this
 */
contract AutoHistory {
    struct Car {
       string vin;
       uint256 kilometers;
       Repair[] repairs;
    }
    
    struct Repair {
        uint256 price;
        string description;
    }
    
    mapping (string => Car) private cars;
    
    /**
     * Get a car's repair + crash history
     */
     function getHistory(string memory vin) view public  {
         
     }
     
    function carExists(string memory vin) private view returns (bool) {
        return bytes(cars[vin].vin).length > 0;
    }
     
    function addCar(string memory vin, uint256 kilometers) public {
        require(!carExists(vin), "Car already exists");
         
        Car memory newCar;
        newCar.vin = vin;
        newCar.kilometers = kilometers;
        cars[vin] = newCar;
    }
    
    function addRepair(string memory vin, uint256 price, string memory description) public {
        require(carExists(vin), "Car does not exist");
        
        cars[vin].repairs.push(Repair(price, description));
    }
     
    function setKilometers(string memory vin, uint256 kilometers) public {
        require(carExists(vin), "Car does not exist");
        
        cars[vin].kilometers = kilometers;
    }
}