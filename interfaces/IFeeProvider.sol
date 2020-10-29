pragma solidity ^0.5.0;

/************
@title IFeeProvider interface
@notice Interface for the Circulate fee provider.
*/

interface IFeeProvider {
    function calculateLoanOriginationFee(address _reserve, uint256 _amount) external view returns (uint256);
    function getLoanOriginationFeePercentage(address _reserve) external view returns (uint256);
}
