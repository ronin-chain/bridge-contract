// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

interface IRoninTrustedOrganization {
  /// @dev Emitted when the trusted organization is added.
  event TrustedOrganizationAdded(address);
  /// @dev Emitted when the trusted organization is removed.
  event TrustedOrganizationRemoved(address);

  /**
   * @dev Adds a list of addresses into the trusted organization.
   *
   * Requirements:
   * - The method caller is admin.
   *
   * Emits the event `TrustedOrganizationAdded` once an organization is added.
   *
   */
  function addTrustedOrganizations(address[] calldata) external;

  /**
   * @dev Removes a list of addresses from the trusted organization.
   *
   * Requirements:
   * - The method caller is admin.
   *
   * Emits the event `TrustedOrganizationRemoved` once an organization is removed.
   *
   */
  function removeTrustedOrganizations(address[] calldata) external;

  /**
   * @dev Returns whether the addresses are trusted organizations.
   */
  function isTrustedOrganizations(address[] calldata) external view returns (bool[] memory);

  /**
   * @dev Returns the trusted organization at `_index`.
   */
  function getTrustedOrganizationAt(uint256 _index) external view returns (address);

  /**
   * @dev Returns the number of trusted organizations.
   */
  function countTrustedOrganizations() external view returns (uint256);

  /**
   * @dev Returns all of the trusted organization addresses.
   */
  function getAllTrustedOrganizations() external view returns (address[] memory);
}
