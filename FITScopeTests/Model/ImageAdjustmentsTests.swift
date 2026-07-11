/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Jean-David Gadina - www.xs-labs.com
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the Software), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED AS IS, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 ******************************************************************************/

@testable import FITScope
import Testing

/// Tests for `ImageAdjustments`: the observable model that drives the pipeline
/// configuration the renderer consumes.
@Suite( "ImageAdjustments" )
struct ImageAdjustmentsTests
{
    /// The adjustments model builds a pipeline configuration whose fields map
    /// across from the settings, and changes to the model flow into the config.
    @Test
    @MainActor
    func adjustmentsBuildPipelineConfig() throws
    {
        let adjustments = ImageAdjustments()

        // The model's defaults equal the settings' defaults.
        #expect( adjustments.settings == ImageProcessor.Settings() )

        let config = adjustments.settings.config( scale: 2, offset: 3, headerPattern: .rggb )

        // Header-derived affine scaling passes through unchanged.
        #expect( config.scale?.scale  == 2 )
        #expect( config.scale?.offset == 3 )

        // The defaults render the file as captured: linear normalization only,
        // with no stretch, white balance or inversion.
        #expect( config.stretch      == nil )
        #expect( config.correctGamma == nil )
        #expect( config.whiteBalance == nil )
        #expect( config.normalize    == .minMax )
        #expect( config.invert       == false )

        // Enabling inversion flows into a freshly built config.
        adjustments.invert = true

        #expect( adjustments.settings.config( scale: 1, offset: 0, headerPattern: nil ).invert )

        // Orientation defaults to identity and is omitted from the config (the
        // image renders as captured).
        #expect( adjustments.orientation.isIdentity )
        #expect( config.orient == nil )

        // A rotation flows into a freshly built config.
        adjustments.orientation = .init( rotation: .clockwise90, mirroredHorizontally: false )

        #expect( adjustments.settings.config( scale: 1, offset: 0, headerPattern: nil ).orient == .init( rotation: .clockwise90, mirroredHorizontally: false ) )

        // Brightness and contrast default to neutral and are omitted from the
        // config (the image renders unadjusted).
        #expect( adjustments.brightness == 0 )
        #expect( adjustments.contrast   == 1 )
        #expect( config.brightnessContrast == nil )

        // Changes flow into a freshly built config.
        adjustments.brightness = 0.2
        adjustments.contrast   = 1.5

        let brightnessContrast = try #require( adjustments.settings.config( scale: 1, offset: 0, headerPattern: nil ).brightnessContrast )

        #expect( brightnessContrast.brightness == 0.2 )
        #expect( brightnessContrast.contrast   == 1.5 )

        // Saturation defaults to neutral (1) and is omitted from the config.
        #expect( adjustments.saturation == 1 )
        #expect( config.saturation == nil )

        // A change flows into a freshly built config.
        adjustments.saturation = 1.4

        #expect( adjustments.settings.config( scale: 1, offset: 0, headerPattern: nil ).saturation == 1.4 )

        // Hue defaults to neutral (0°) and is omitted from the config.
        #expect( adjustments.hue == 0 )
        #expect( config.hue == nil )

        // A change flows into a freshly built config.
        adjustments.hue = 30

        #expect( adjustments.settings.config( scale: 1, offset: 0, headerPattern: nil ).hue == 30 )

        // Colour balance defaults to neutral and is omitted from the config.
        #expect( adjustments.colorBalance == .identity )
        #expect( config.colorBalance == nil )

        // A change flows into a freshly built config.
        adjustments.colorBalance = .init( midtones: .init( red: 0.2 ) )

        let colorBalance = adjustments.settings.config( scale: 1, offset: 0, headerPattern: nil ).colorBalance

        #expect( colorBalance == adjustments.colorBalance )

        // Levels default to an identity uniform mapping and are omitted from the
        // config (the image renders unadjusted).
        #expect( adjustments.levels == .uniform( .identity ) )
        #expect( config.levels == nil )

        // A non-identity levels remap flows into a freshly built config.
        adjustments.levels = .uniform( .init( inputBlack: 0.1, inputWhite: 0.9, gamma: 1.5 ) )

        #expect( adjustments.settings.config( scale: 1, offset: 0, headerPattern: nil ).levels == .uniform( .init( inputBlack: 0.1, inputWhite: 0.9, gamma: 1.5 ) ) )

        // Curves default to an identity uniform curve and are omitted from the
        // config (the image renders unadjusted).
        #expect( adjustments.curves == .uniform( .identity ) )
        #expect( config.curves == nil )

        // A non-identity tone curve flows into a freshly built config.
        adjustments.curves = .uniform( .init( points: [ .init( x: 0, y: 0 ), .init( x: 0.5, y: 0.7 ), .init( x: 1, y: 1 ) ] ) )

        #expect( adjustments.settings.config( scale: 1, offset: 0, headerPattern: nil ).curves == .uniform( .init( points: [ .init( x: 0, y: 0 ), .init( x: 0.5, y: 0.7 ), .init( x: 1, y: 1 ) ] ) ) )

        // The default .auto debayer selection uses the header pattern, giving a
        // CFA input format the pipeline demosaics.
        #expect( config.inputFormat == .cfa( pattern: .rggb, mode: .bilinear ) )

        // A changed setting flows into a freshly built config, and an explicit
        // debayer pattern overrides the header.
        adjustments.stretch = .uniform( .init( midtones: 0.3 ) )
        adjustments.debayer = .pattern( .grbg )

        let updated = adjustments.settings.config( scale: 1, offset: 0, headerPattern: .bggr )

        #expect( updated.stretch     == .uniform( .init( midtones: 0.3 ) ) )
        #expect( updated.inputFormat == .cfa( pattern: .grbg, mode: .bilinear ) )
    }

    /// `reset()` restores every adjustment to its default in one place, so the
    /// inspector's Reset View button and the Image menu share the same reset
    /// rather than each duplicating the field-by-field copy.
    @Test
    @MainActor
    func resetRestoresEveryValueToItsDefault()
    {
        let adjustments = ImageAdjustments()

        // Move a spread of fields — simple values, the mode/enum pipeline stages,
        // and orientation — away from their defaults.
        adjustments.invert       = true
        adjustments.brightness   = 0.5
        adjustments.contrast     = 2.0
        adjustments.saturation   = 0.5
        adjustments.hue          = 45
        adjustments.colorBalance = .init( midtones: .init( red: 0.2 ) )
        adjustments.stretch      = .uniform( .init( midtones: 0.3 ) )
        adjustments.levels       = .uniform( .init( inputBlack: 0.1, inputWhite: 0.9, gamma: 1.5 ) )
        adjustments.curves       = .uniform( .init( points: [ .init( x: 0, y: 0 ), .init( x: 0.5, y: 0.7 ), .init( x: 1, y: 1 ) ] ) )
        adjustments.debayer      = .pattern( .grbg )
        adjustments.orientation  = .init( rotation: .clockwise90, mirroredHorizontally: false )

        adjustments.reset()

        // One equality covers every pipeline field the settings encode; the
        // orientation is checked explicitly for clarity.
        #expect( adjustments.settings == ImageProcessor.Settings() )
        #expect( adjustments.orientation.isIdentity )
    }

    /// Values imperceptibly close to their neutral point — e.g. floating-point
    /// drift from a slider dragged back toward neutral — are treated as neutral
    /// and omitted from the config, so their pipeline stage is not run
    /// needlessly. A genuine, perceptible deviation is still applied.
    @Test
    @MainActor
    func neutralValuesAreOmittedWithinTolerance()
    {
        let adjustments = ImageAdjustments()

        adjustments.saturation = 1 - 1e-9
        adjustments.brightness = 1e-9
        adjustments.contrast   = 1 + 1e-9
        adjustments.hue        = 1e-9

        let neutral = adjustments.settings.config( scale: 1, offset: 0, headerPattern: nil )

        #expect( neutral.saturation         == nil )
        #expect( neutral.brightnessContrast == nil )
        #expect( neutral.hue                == nil )

        adjustments.saturation = 1.5
        adjustments.brightness = 0.5
        adjustments.contrast   = 1.5
        adjustments.hue        = 45

        let applied = adjustments.settings.config( scale: 1, offset: 0, headerPattern: nil )

        #expect( applied.saturation   == 1.5 )
        #expect( applied.hue          == 45 )
        #expect( applied.brightnessContrast?.brightness == 0.5 )
        #expect( applied.brightnessContrast?.contrast   == 1.5 )
    }

    /// `hasAdjustments` reports whether any value deviates from the pipeline
    /// defaults, so the sidebar can mark files whose image has been edited.
    @Test
    @MainActor
    func hasAdjustmentsTracksDeviationFromDefaults()
    {
        let adjustments = ImageAdjustments()

        // A freshly created set renders the file as captured, so it has no
        // adjustments.
        #expect( adjustments.hasAdjustments == false )

        // A simple value change away from the defaults counts as an adjustment.
        adjustments.brightness = 0.3

        #expect( adjustments.hasAdjustments )

        // Resetting clears the flag again.
        adjustments.reset()

        #expect( adjustments.hasAdjustments == false )

        // A non-value pipeline stage (orientation) counts too.
        adjustments.orientation = .init( rotation: .clockwise90, mirroredHorizontally: false )

        #expect( adjustments.hasAdjustments )
    }

    // MARK: - Per-image baseline

    /// A non-default baseline seeds the initial adjustment values, so a format
    /// whose samples are already display-ready (e.g. a photographic image) opens
    /// as authored rather than range-stretched.
    @Test
    @MainActor
    func baselineSeedsInitialValues()
    {
        let baseline    = ImageProcessor.Settings( normalize: .identity, invert: true )
        let adjustments = ImageAdjustments( baseline: baseline )

        #expect( adjustments.baseline == baseline )
        #expect( adjustments.normalize == .identity )
        #expect( adjustments.invert )
        #expect( adjustments.settings == baseline )
    }

    /// `hasAdjustments` compares against the per-image baseline, not the pipeline
    /// defaults, so an unmodified image with a non-default baseline is not marked
    /// as edited.
    @Test
    @MainActor
    func hasAdjustmentsComparesToBaseline()
    {
        let adjustments = ImageAdjustments( baseline: ImageProcessor.Settings( normalize: .identity ) )

        // The image opens on its baseline, so it has no adjustments even though the
        // baseline differs from the pipeline defaults.
        #expect( adjustments.hasAdjustments == false )

        // Moving away from the baseline counts as an adjustment.
        adjustments.brightness = 0.3

        #expect( adjustments.hasAdjustments )

        // Reset returns to the baseline, clearing the flag.
        adjustments.reset()

        #expect( adjustments.hasAdjustments == false )
        #expect( adjustments.normalize == .identity, "reset returns to the baseline, not the pipeline default" )
    }

    /// `reset()` restores every field to the per-image baseline, so a photographic
    /// image resets to its as-authored view rather than the min/max default.
    @Test
    @MainActor
    func resetRestoresToBaseline()
    {
        let baseline    = ImageProcessor.Settings( normalize: .identity )
        let adjustments = ImageAdjustments( baseline: baseline )

        adjustments.normalize  = .minMax
        adjustments.brightness = 0.5
        adjustments.stretch    = .uniform( .init( midtones: 0.3 ) )

        adjustments.reset()

        #expect( adjustments.settings == baseline )
    }

    /// The per-field `isModified(_:)` and `reset(_:)` also compare against and
    /// restore to the per-image baseline.
    @Test
    @MainActor
    func perFieldModificationComparesToBaseline()
    {
        let adjustments = ImageAdjustments( baseline: ImageProcessor.Settings( invert: true ) )

        // The baseline has invert on, so an unmodified image is not "modified".
        #expect( adjustments.isModified( \.invert ) == false )

        // Turning inversion off is a deviation from this image's baseline.
        adjustments.invert = false

        #expect( adjustments.isModified( \.invert ) )

        // The per-field reset returns to the baseline value, not the pipeline default.
        adjustments.reset( \.invert )

        #expect( adjustments.invert )
        #expect( adjustments.isModified( \.invert ) == false )
    }

    // MARK: - Per-field reset

    /// `isModified(_:)` reports whether a single field differs from its default,
    /// so a per-control reset affordance can show only when its control is edited.
    @Test
    @MainActor
    func isModifiedReportsPerFieldDeviation()
    {
        let adjustments = ImageAdjustments()

        #expect( adjustments.isModified( \.invert )     == false )
        #expect( adjustments.isModified( \.brightness ) == false )

        adjustments.invert = true

        #expect( adjustments.isModified( \.invert ) )
        #expect( adjustments.isModified( \.brightness ) == false, "only the changed field reports as modified" )
    }

    /// `reset(_:)` restores a single field to its default while leaving the others
    /// untouched, so one control can be reset without resetting the whole view.
    @Test
    @MainActor
    func resetRestoresASingleFieldLeavingOthers()
    {
        let adjustments = ImageAdjustments()

        adjustments.brightness = 0.5
        adjustments.contrast   = 1.5

        adjustments.reset( \.brightness )

        #expect( adjustments.brightness == 0 )
        #expect( adjustments.contrast   == 1.5, "resetting one field must not touch the others" )
    }

    /// The key-path reset works for the non-numeric pipeline fields the
    /// section-level resets act on — the enum modes and the orientation.
    @Test
    @MainActor
    func perFieldResetWorksForModeAndOrientationFields()
    {
        let adjustments = ImageAdjustments()

        adjustments.stretch     = .uniform( .init( midtones: 0.3 ) )
        adjustments.orientation = .init( rotation: .clockwise90, mirroredHorizontally: false )

        #expect( adjustments.isModified( \.stretch ) )
        #expect( adjustments.isModified( \.orientation ) )

        adjustments.reset( \.stretch )
        adjustments.reset( \.orientation )

        #expect( adjustments.isModified( \.stretch ) == false )
        #expect( adjustments.orientation.isIdentity )
    }
}
