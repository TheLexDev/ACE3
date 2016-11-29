/*
 * Author: commy2
 * Main HandleDamage EH function for soldiers.
 *
 * Arguments:
 * Handle damage EH
 *
 * Return Value:
 * Damage to be inflicted <NUMBER>
 *
 * Public: No
 */
#include "script_component.hpp"

// for travis
#define HIT_STRUCTURAL QGVAR($#structural)
#define HIT_CRASH QGVAR($#crash)

params ["_unit", "_selection", "_damage", "_shooter", "_ammo", "_hitPointIndex", "_instigator"];
//diag_log text str _this;

// HD sometimes triggers for remote units - ignore.
if (!local _unit) exitWith {nil};

// Get missing meta info
private ["_hitPoint", "_oldDamage"];
private _isCrash = false;

// Store
if (_hitPointIndex < 0) then {
    _hitPoint = "#structural";
    _oldDamage = damage _unit;

    // Handle vehicle crashes
    if (_damage == _unit getVariable [HIT_CRASH, -1]) then {
        _isCrash = true;
        _unit setVariable [HIT_CRASH, -1];
    } else {
        _unit setVariable [HIT_CRASH, _damage];
    };
} else {
    _hitPoint = toLower (getAllHitPointsDamage _unit select 0 select _hitPointIndex);
    _oldDamage = _unit getHitIndex _hitPointIndex;

    // No crash, reset
    _unit setVariable [HIT_CRASH, -1];
};

private _newDamage = _damage - _oldDamage;
_unit setVariable [format [QGVAR($%1), _hitPoint], _newDamage];

// These control blood material visuals.
// If damage is in dummy hitpoints, "hands" and "legs", don't change anything
if (_hitPoint in ["hithead", "hitbody", "hithands", "hitlegs"]) exitWith {_oldDamage};

// Add injury
if (_hitPoint isEqualTo "ace_hdbracket") exitWith {
    _unit setVariable [QGVAR(lastShooter), _shooter];
    _unit setVariable [QGVAR(lastInstigator), _instigator];

    private _damageStructural = _unit getVariable [HIT_STRUCTURAL, 0];

    // --- Head
    private _damageFace = _unit getVariable [QGVAR($HitFace), 0];
    private _damageNeck = _unit getVariable [QGVAR($HitNeck), 0];
    private _damageHead = (_unit getVariable [QGVAR($HitHead), 0]) max _damageFace max _damageNeck;

    // --- Body
    private _damagePelvis = _unit getVariable [QGVAR($HitPelvis), 0];
    private _damageAbdomen = _unit getVariable [QGVAR($HitAbdomen), 0];
    private _damageDiaphragm = _unit getVariable [QGVAR($HitDiaphragm), 0];
    private _damageChest = _unit getVariable [QGVAR($HitChest), 0];
    private _damageBody = (_unit getVariable [QGVAR($HitBody), 0]) max _damagePelvis max _damageAbdomen max _damageDiaphragm max _damageChest;

    // --- Arms and Legs
    private _damageLeftArm = _unit getVariable [QGVAR($HitLeftArm), 0];
    private _damageRightArm = _unit getVariable [QGVAR($HitRightArm), 0];
    private _damageLeftLeg = _unit getVariable [QGVAR($HitLeftLeg), 0];
    private _damageRightLeg = _unit getVariable [QGVAR($HitRightLeg), 0];

    // Find hit point that received the maxium damage.
    // second param is a priority. should multiple hitpoints receive the same
    // amount of damage (e.g. max which is 4), we don't want them to be sorted
    // alphabetically (which would mean that RightLeg is always chosen)
    private _allDamages = [
        [_damageHead,     PRIORITY_HEAD,      "Head"],
        [_damageBody,     PRIORITY_BODY,      "Body"],
        [_damageLeftArm,  PRIORITY_LEFT_ARM,  "LeftArm"],
        [_damageRightArm, PRIORITY_RIGHT_ARM, "RightArm"],
        [_damageLeftLeg,  PRIORITY_LEFT_LEG,  "LeftLeg"],
        [_damageRightLeg, PRIORITY_RIGHT_LEG, "RightLeg"]
    ];
    TRACE_2("incoming",_allDamages,_damageStructural);

    _allDamages sort false;
    (_allDamages select 0) params ["_receivedDamage", "", "_woundedHitPoint"];

    if (_receivedDamage == 0) then {
        _receivedDamage = _damageStructural;
        _woundedHitPoint = "Body";
    };
    TRACE_2("received",_receivedDamage,_woundedHitPoint);

    // Check for falling damage.
    if (_ammo isEqualTo "") then {
        if (velocity _unit select 2 < -2) then {
            if (_receivedDamage < 0.35) then {
                // Less than ~ 5 m
                _woundedHitPoint = selectRandom ["LeftLeg", "RightLeg"];
            } else {
                // More than ~ 5 m
                _woundedHitPoint = selectRandom ["LeftLeg", "RightLeg", "Body", "Head"];
            };
            _ammo = "#falling";
        } else {
            // Assume collision damage.
            // @todo, find a method for detecting burning damage.
            _woundedHitPoint = "Body";
            _ammo = "#collision";
        };
    };

    // Don't trigger for minor damage.
    if (_receivedDamage > 1E-3) then {
        [QGVAR(woundReceived), [_unit, _woundedHitPoint, _receivedDamage, _shooter, _ammo]] call CBA_fnc_localEvent;
    };

    0
};

// Check for drowning damage.
// Don't change the third expression. Safe method for FLOATs.
if (_hitPoint isEqualTo "#structural" && {getOxygenRemaining _unit <= 0.5} && {_damage isEqualTo (_oldDamage + 0.005)}) exitWith {
    [QGVAR(woundReceived), [_unit, "Body", _newDamage, _unit, "#drowning"]] call CBA_fnc_localEvent;

    0
};

// Handle vehicle crashes
if (_isCrash) exitWith {
    [QGVAR(woundReceived), [_unit, "Body", _newDamage, _unit, "#vehiclecrash"]] call CBA_fnc_localEvent;

    0
};

0
