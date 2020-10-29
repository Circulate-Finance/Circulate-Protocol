pragma solidity ^0.5.0;

import "../interfaces/IFeeProvider.sol";
import "../libraries/WadRayMath.sol";
import "../Ownable.sol";


/**
* @title FeeProvider contract
* @notice Implements calculation for the fees applied by the protocol
* @author Circulate
**/
contract FeeProvider is IFeeProvider, Ownable {
    using WadRayMath for uint256;

    // percentage of the fee to be calculated on the loan amount,  origination fee is set as default as 25 basis points of the loan amount (0.0025%) = 0.0025 * 1e18
    mapping(address => uint256) public reserve2feePercentage;

    function setReserveFeePercentage(address _reserve, uint _feePercentage) public onlyOwner {
        reserve2feePercentage[_reserve] = _feePercentage;
    }

    /**
    * @dev calculates the origination fee for every loan executed on the platform.
    * @param _reserve apply discount to the origination fee based on the
    * _reserve account
    * @param _amount the amount of the loan
    **/
    function calculateLoanOriginationFee(address _reserve, uint256 _amount) external view returns (uint256) {
        return _amount.wadMul(reserve2feePercentage[_reserve]);
    }

    /**
    * @dev returns the origination fee percentage
    **/
    function getLoanOriginationFeePercentage(address _reserve) external view returns (uint256) {
        return reserve2feePercentage[_reserve];
    }

}
