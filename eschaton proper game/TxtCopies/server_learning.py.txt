#!/usr/bin/env python3
"""
ESCHATON — Local Hive-Mind Learning Server
Reads run telemetry and adapts AI weights using heuristic rules.
Sprints 11 & 12: Adaptive spawn rates, cover density, and hazard density.
"""

import json
import os
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
RUN_DATA_PATH = os.path.join(SCRIPT_DIR, "run_data.json")
WEIGHTS_PATH = os.path.join(SCRIPT_DIR, "weights.json")


def load_json(path: str) -> dict:
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def save_json(path: str, data: dict) -> None:
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)


def clamp(value: float, lo: float = 0.0, hi: float = 1.0) -> float:
    return max(lo, min(hi, value))


def normalize_rates(rates: dict) -> dict:
    """Normalize spawn rates so they sum to 1.0, clamped to [0.05, 0.9]."""
    # Clamp individual values
    for key in rates:
        rates[key] = max(0.05, min(0.9, rates[key]))
    # Normalize to sum to 1.0
    total = sum(rates.values())
    if total > 0:
        for key in rates:
            rates[key] = round(rates[key] / total, 3)
    return rates


def adapt(run_data: dict, weights: dict) -> dict:
    aggression = weights.get("aggression", 0.5)
    cowardice = weights.get("cowardice", 0.0)
    flanking = weights.get("flanking", 0.5)
    cover_density = weights.get("cover_density", 0.2)
    hazard_density = weights.get("hazard_density", 0.1)
    spawn_rates = weights.get("spawn_rates", {
        "GRUNT": 0.8,
        "AEGIS": 0.1,
        "FROST": 0.1,
    })

    # ================================================================
    # Original heuristic rules
    # ================================================================

    # Rule 1: If the player won, the AI needs to be harder.
    if run_data.get("result") == "Win":
        aggression += 0.2

    # Rule 2: If thermal > cryo, player relies on ranged lasers.
    #         AI should flank more (dodge LoS) and be slightly less aggressive.
    thermal = run_data.get("thermal_attacks_used", 0)
    cryo = run_data.get("cryo_attacks_used", 0)
    if thermal > cryo:
        flanking += 0.3
        aggression -= 0.1

    # Rule 3: If total_attacks > 5, the player is rushing.
    #         Increase cowardice so enemies kite the player.
    if run_data.get("total_attacks", 0) > 5:
        cowardice += 0.3

    # ================================================================
    # Sprint 12: Counter-measure spawn rate adaptation
    # ================================================================

    # Counter-Measure: If thermal_used > 5, spawn more AEGIS (thermal-resistant)
    if thermal > 5:
        spawn_rates["AEGIS"] = spawn_rates.get("AEGIS", 0.1) + 0.3

    # Counter-Measure: If cryo_used > 5, spawn more FROST (cryo-resistant)
    if cryo > 5:
        spawn_rates["FROST"] = spawn_rates.get("FROST", 0.1) + 0.3

    # ================================================================
    # Sprint 22: Status Effects handling
    # ================================================================
    burn_damage = run_data.get("burn_damage_dealt", 0)
    turns_frozen = run_data.get("turns_enemies_frozen", 0)

    # Counter-Measure: If burn_damage > 20, player relies on burn.
    # Spawn more AEGIS (Immune) and increase hazard pools (Water cures burn)
    if burn_damage > 20:
        spawn_rates["AEGIS"] = spawn_rates.get("AEGIS", 0.1) + 0.2
        hazard_density += 0.1
        
    # Counter-Measure: If turns_frozen > 10, player relies on freeze.
    # Spawn more FROST (Immune)
    if turns_frozen > 10:
        spawn_rates["FROST"] = spawn_rates.get("FROST", 0.1) + 0.2

    # Normalize spawn rates so they always sum to 1.0
    spawn_rates = normalize_rates(spawn_rates)

    # ================================================================
    # Sprint 11: Adaptive hazard density
    # ================================================================

    # If the player hides behind walls (avg distance > 6.0), flush them out
    avg_dist = run_data.get("avg_distance_from_enemies", 0.0)
    if avg_dist > 6.0:
        hazard_density += 0.1

    # Clamp all weights
    weights["aggression"] = clamp(aggression)
    weights["cowardice"] = clamp(cowardice)
    weights["flanking"] = clamp(flanking)
    weights["cover_density"] = clamp(cover_density, 0.05, 0.4)
    weights["hazard_density"] = clamp(hazard_density, 0.0, 0.3)
    weights["spawn_rates"] = spawn_rates

    return weights


def main() -> None:
    # --- Load run data ---
    if not os.path.exists(RUN_DATA_PATH):
        print(f"ERROR: Run data not found at {RUN_DATA_PATH}")
        sys.exit(1)

    run_data = load_json(RUN_DATA_PATH)

    # --- Load current weights ---
    if not os.path.exists(WEIGHTS_PATH):
        print(f"ERROR: Weights file not found at {WEIGHTS_PATH}")
        sys.exit(1)

    weights = load_json(WEIGHTS_PATH)

    # --- Adapt ---
    weights = adapt(run_data, weights)

    # --- Save ---
    save_json(WEIGHTS_PATH, weights)

    # --- Summary ---
    sr = weights["spawn_rates"]
    floor_reached = run_data.get("highest_floor_reached", 1)
    print(f"\nESCHATON LEARNED FROM YOUR DEATH ON FLOOR {floor_reached}")
    print(
        f"ESCHATON ADAPTED: "
        f"Aggression {weights['aggression']:.2f}, "
        f"Cowardice {weights['cowardice']:.2f}, "
        f"Flanking {weights['flanking']:.2f} | "
        f"Cover {weights['cover_density']:.2f}, "
        f"Hazard {weights['hazard_density']:.2f} | "
        f"GRUNT {sr['GRUNT']:.0%}, "
        f"AEGIS {sr['AEGIS']:.0%}, "
        f"FROST {sr['FROST']:.0%}"
    )
    
    # Optional debug print for Status Effects
    bd = run_data.get("burn_damage_dealt", 0)
    tf = run_data.get("turns_enemies_frozen", 0)
    if bd > 0 or tf > 0:
        print(f"STATUS DATA OBSERVED: Burn Dmg: {bd}, Turns Frozen: {tf}")


if __name__ == "__main__":
    main()
