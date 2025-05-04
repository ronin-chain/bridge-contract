// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IPauseEnforcer {
  error ErrNotOnEmergencyPause();
  error ErrTargetIsNotOnPaused();
  error ErrTargetIsOnPaused();

  event EmergencyPaused(address account);
  event EmergencyUnpaused(address account);
  event Initialized(uint8 version);
  event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);
  event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
  event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);
  event TargetChanged(address target);

  function DEFAULT_ADMIN_ROLE() external view returns (bytes32);
  function SENTRY_ROLE() external view returns (bytes32);
  function changeTarget(
    address _target
  ) external;
  function emergency() external view returns (bool);
  function getRoleAdmin(
    bytes32 role
  ) external view returns (bytes32);
  function getRoleMember(bytes32 role, uint256 index) external view returns (address);
  function getRoleMemberCount(
    bytes32 role
  ) external view returns (uint256);
  function grantRole(bytes32 role, address account) external;
  function grantSentry(
    address _sentry
  ) external;
  function hasRole(bytes32 role, address account) external view returns (bool);
  function initialize(address _target, address _admin, address[] memory _sentries) external;
  function renounceRole(bytes32 role, address account) external;
  function revokeRole(bytes32 role, address account) external;
  function revokeSentry(
    address _sentry
  ) external;
  function supportsInterface(
    bytes4 interfaceId
  ) external view returns (bool);
  function target() external view returns (address);
  function triggerPause() external;
  function triggerUnpause() external;
  function triggerRestrict(bytes4 fnSig, uint8 enumBitmap) external;
}
