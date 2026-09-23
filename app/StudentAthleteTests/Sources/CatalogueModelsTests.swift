import XCTest

/// Every fixture below is copied verbatim (trimmed for length, never
/// hand-invented) from a real `content && npm run build` output, so these
/// tests prove the decode logic against the actual shape content/ produces,
/// not a guessed-at approximation of §7's prose description.
final class CatalogueModelsTests: XCTestCase {
    func testDecodesACorePackItemWithNoOptionalFields() throws {
        let json = """
        {
          "slug": "acceleration-wall-drill",
          "name": "Acceleration Wall Drill",
          "kind": "exercise",
          "qualities": { "acceleration": 1, "ankle-stiffness": 0.5 },
          "muscles": { "gluteus-maximus": 0.8, "gastrocnemius": 0.6, "rectus-femoris": 0.5 },
          "equipment": ["wall"],
          "surface": "anywhere",
          "minAge": 13,
          "supervisionLevel": "SELF",
          "setup": ["Lean into a wall at about 45 degrees, hands at shoulder height."],
          "execution": ["Drive one knee up to hip height while the other leg stays extended behind."],
          "cues": ["Shin drives forward, not the foot kicking back."],
          "mistakes": ["Bending at the waist instead of leaning as one straight line from the wall."],
          "progressions": ["sled-push"],
          "regressions": ["acceleration-march"],
          "substitutes": ["acceleration-march"],
          "defaultDose": { "kind": "time", "sets": 3, "seconds": 20, "load": "bodyweight" },
          "restSeconds": 60,
          "startPose": "sprint-cycle",
          "endPose": "sprint-cycle",
          "unilateralEligible": false,
          "tempoEligible": false
        }
        """
        let item = try JSONDecoder().decode(CatalogueItem.self, from: Data(json.utf8))

        XCTAssertEqual(item.slug, "acceleration-wall-drill")
        XCTAssertEqual(item.kind, "exercise")
        XCTAssertEqual(item.qualities["acceleration"], 1)
        XCTAssertEqual(item.equipment, ["wall"])
        XCTAssertEqual(item.defaultDose.kind, "time")
        XCTAssertEqual(item.defaultDose.seconds, 20)
        XCTAssertFalse(item.isUnilateralEligible)
        XCTAssertFalse(item.isCoached)
        // Keys entirely absent from a real core-pack item decode to nil, not
        // a crash.
        XCTAssertNil(item.prop)
        XCTAssertNil(item.variant)
        XCTAssertNil(item.itemSportSlug)
        XCTAssertNil(item.equipmentChain)
        XCTAssertNil(item.constraintAxes)
    }

    func testDecodesAnItemWithEquipmentChainAndUnilateralFields() throws {
        let json = """
        {
          "slug": "trap-bar-deadlift",
          "name": "Trap-Bar Deadlift",
          "kind": "exercise",
          "qualities": { "lower-body-strength": 1, "grip": 0.5 },
          "muscles": { "gluteus-maximus": 1, "erector-spinae": 0.7 },
          "equipment": ["trap-bar", "weight-plate"],
          "surface": "gym",
          "minAge": 14,
          "supervisionLevel": "SELF",
          "setup": ["Stand inside the trap bar, feet hip-width."],
          "execution": ["Hinge and grip the handles, then drive through the floor to stand tall."],
          "cues": ["Push the floor away."],
          "mistakes": ["Letting the hips shoot up first."],
          "progressions": [],
          "regressions": [],
          "substitutes": ["single-leg-rdl"],
          "defaultDose": { "kind": "reps", "sets": 3, "reps": 6, "load": "moderate" },
          "restSeconds": 120,
          "startPose": "hinge",
          "endPose": "hinge",
          "equipmentChain": [
            { "tier": "trap-bar", "label": "trap bar", "equipment": ["trap-bar", "weight-plate"] },
            { "tier": "bodyweight", "label": "bodyweight squat", "equipment": ["none"] }
          ],
          "unilateralEligible": true,
          "unilateralPosePattern": "single-leg-rdl",
          "unilateralStabilityQuality": "single-leg-stability",
          "tempoEligible": true
        }
        """
        let item = try JSONDecoder().decode(CatalogueItem.self, from: Data(json.utf8))

        XCTAssertTrue(item.isUnilateralEligible)
        XCTAssertTrue(item.isTempoEligible)
        XCTAssertEqual(item.unilateralPosePattern, "single-leg-rdl")
        XCTAssertEqual(item.equipmentChain?.count, 2)
        XCTAssertEqual(item.equipmentChain?.first?.tier, "trap-bar")
        XCTAssertEqual(item.equipmentChain?.first?.equipment, ["trap-bar", "weight-plate"])
    }

    func testDecodesASportDrillWithConstraintAxesPropAndItsOwnSportSlug() throws {
        let json = """
        {
          "slug": "volleyball-approach-and-swing-footwork",
          "name": "Approach-and-Swing Footwork",
          "kind": "drill",
          "sport": "volleyball",
          "qualities": { "vertical-power": 0.8, "change-of-direction": 0.6 },
          "muscles": { "gluteus-maximus": 0.7, "deltoid-anterior": 0.6 },
          "equipment": ["ball", "net"],
          "prop": "ball-round",
          "surface": "court",
          "minAge": 13,
          "supervisionLevel": "SELF",
          "setup": ["Stand at the approach spot, a few steps back from the net."],
          "execution": ["Perform the three- or four-step approach building speed into the plant."],
          "cues": ["The last two steps should be quick and low."],
          "mistakes": ["A slow, even-tempo approach."],
          "progressions": [],
          "regressions": [],
          "substitutes": [],
          "defaultDose": { "kind": "reps", "sets": 4, "reps": 6, "load": "bodyweight" },
          "restSeconds": 60,
          "startPose": "vertical-jump",
          "endPose": "overhead-throw",
          "constraintAxes": ["opposition"]
        }
        """
        let item = try JSONDecoder().decode(CatalogueItem.self, from: Data(json.utf8))

        // The item's OWN "sport" key must land on itemSportSlug, not be
        // confused with CataloguePack.sport (the pack-level SportInfo object).
        XCTAssertEqual(item.itemSportSlug, "volleyball")
        XCTAssertEqual(item.prop, "ball-round")
        XCTAssertEqual(item.constraintAxes, ["opposition"])
        XCTAssertFalse(item.isUnilateralEligible)
        XCTAssertFalse(item.isTempoEligible)
    }

    func testDecodesASportInfoObjectWithPositionsAndSkills() throws {
        let json = """
        {
          "slug": "basketball",
          "name": "Basketball",
          "governing": ["NFHS", "NCAA"],
          "season": "WINTER",
          "monthRange": [11, 3],
          "qualityProfile": { "vertical-power": 0.9, "change-of-direction": 0.9 },
          "positions": [
            { "slug": "guard", "name": "Guard", "qualityProfile": { "change-of-direction": 1 } },
            { "slug": "center", "name": "Center", "qualityProfile": { "vertical-power": 1 } }
          ],
          "skills": [
            { "slug": "vertical-jump", "name": "Vertical jump", "qualityWeights": { "vertical-power": 1.0 } },
            { "slug": "first-step", "name": "First step", "qualityWeights": { "acceleration": 1.0 } },
            { "slug": "shooting-mechanics", "name": "Shooting mechanics", "qualityWeights": { "shoulder-stability": 0.8 } },
            { "slug": "ball-handling", "name": "Ball handling", "qualityWeights": { "change-of-direction": 0.8 } }
          ],
          "commonLoadAreas": ["knees", "ankles", "lower-back"],
          "contactLevel": "CONTACT",
          "typicalSessionLength": 90,
          "typicalWeeklyGames": 2
        }
        """
        let sport = try JSONDecoder().decode(SportInfo.self, from: Data(json.utf8))

        XCTAssertEqual(sport.slug, "basketball")
        XCTAssertEqual(sport.monthRange, [11, 3])
        XCTAssertEqual(sport.positions.count, 2)
        XCTAssertEqual(sport.skills.count, 4)
        XCTAssertEqual(sport.typicalWeeklyGames, 2)
    }

    /// A full pack, core-shaped (no `sport` key at the top level).
    func testDecodesACorePackWithNoSportObject() throws {
        let json = """
        {
          "slug": "core",
          "version": 1,
          "generatedAt": "2026-01-01T00:00:00.000Z",
          "qualityModelVersion": 1,
          "muscleModelVersion": 1,
          "poseModelVersion": 1,
          "items": []
        }
        """
        let pack = try JSONDecoder().decode(CataloguePack.self, from: Data(json.utf8))
        XCTAssertNil(pack.sport)
        XCTAssertEqual(pack.slug, "core")
    }
}
