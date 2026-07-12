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
import SwiftPixel
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

    /// A distinct `opened` state (an auto-applied stretch on open) seeds the initial
    /// values, but the reset target stays the unstretched baseline. So the image is
    /// not flagged as edited on open (``hasAdjustments`` compares to `opened`), yet
    /// the stretch is a resettable adjustment over the baseline, and ``reset()``
    /// returns to the unstretched view — after which the image reads as adjusted.
    @Test
    @MainActor
    func openedStateSeedsCurrentButResetReturnsToBaseline()
    {
        let baseline    = ImageProcessor.Settings()
        let stretch     = Processors.Stretch.STFParameters.uniform( .init( midtones: 0.3 ) )
        let opened      = ImageProcessor.Settings( normalize: .identity, stretch: stretch )
        let adjustments = ImageAdjustments( baseline: baseline, opened: opened )

        // The image opens in the stretched "opened" state.
        #expect( adjustments.stretch   == stretch )
        #expect( adjustments.normalize == .identity )
        #expect( adjustments.settings  == opened )
        #expect( adjustments.opened    == opened )
        #expect( adjustments.baseline  == baseline )

        // Not flagged as edited on open (compares to `opened`, not `baseline`)...
        #expect( adjustments.hasAdjustments == false )

        // ...but the stretch is a resettable adjustment over the unstretched baseline.
        #expect( adjustments.isModified( \.stretch ) )

        adjustments.reset()

        // Reset returns to the unstretched baseline, which differs from `opened`, so
        // the image now reads as adjusted.
        #expect( adjustments.stretch   == nil )
        #expect( adjustments.normalize == .minMax )
        #expect( adjustments.hasAdjustments )
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

    // MARK: - Managed auto-stretch ("Auto engaged")

    /// The managed "Auto engaged" state is seeded from how the image opened: an image
    /// that opened auto-stretched (an `opened` state carrying a stretch) starts
    /// engaged, while an image that opened linear — with the pipeline defaults or a
    /// distinct but unstretched baseline — does not.
    @Test
    @MainActor
    func autoStretchEngagedReflectsHowTheImageOpened()
    {
        // Opened linear on the pipeline defaults: not managed.
        #expect( ImageAdjustments().isAutoStretch == false )

        // A non-default but unstretched baseline still opens linear: not managed.
        #expect( ImageAdjustments( baseline: ImageProcessor.Settings( normalize: .identity ) ).isAutoStretch == false )

        // Opened with an auto-applied stretch: managed on open.
        let stretch = Processors.Stretch.STFParameters.uniform( .init( midtones: 0.3 ) )
        let opened  = ImageProcessor.Settings( normalize: .identity, stretch: stretch )
        let managed = ImageAdjustments( baseline: ImageProcessor.Settings(), opened: opened )

        #expect( managed.isAutoStretch )
    }

    /// Being merely opened auto-stretched does not, by itself, mark the image as
    /// edited: the "Auto engaged" state is not part of the settings snapshot, so
    /// `hasAdjustments` stays `false` until the user changes something.
    @Test
    @MainActor
    func autoStretchAloneDoesNotMarkTheImageEdited()
    {
        let stretch = Processors.Stretch.STFParameters.uniform( .init( midtones: 0.3 ) )
        let opened  = ImageProcessor.Settings( stretch: stretch )
        let managed = ImageAdjustments( baseline: ImageProcessor.Settings(), opened: opened )

        #expect( managed.isAutoStretch )
        #expect( managed.hasAdjustments == false )
    }

    /// Hand-editing the stretch disengages the managed mode: any direct change to the
    /// stretch — a new value, or clearing it (mode → None) — drops out of "Auto
    /// engaged".
    @Test
    @MainActor
    func manualStretchEditDisengagesAutoStretch()
    {
        let stretch = Processors.Stretch.STFParameters.uniform( .init( midtones: 0.3 ) )
        let opened  = ImageProcessor.Settings( stretch: stretch )

        // Editing the stretch to a new value disengages.
        let edited = ImageAdjustments( baseline: ImageProcessor.Settings(), opened: opened )

        #expect( edited.isAutoStretch )

        edited.stretch = .uniform( .init( midtones: 0.6 ) )

        #expect( edited.isAutoStretch == false )

        // Clearing the stretch (mode → None) also disengages.
        let cleared = ImageAdjustments( baseline: ImageProcessor.Settings(), opened: opened )

        #expect( cleared.isAutoStretch )

        cleared.stretch = nil

        #expect( cleared.isAutoStretch == false )
    }

    /// A change to any other adjustment does not disengage the managed mode — only a
    /// stretch edit does — so nudging brightness leaves the auto stretch engaged.
    @Test
    @MainActor
    func nonStretchEditKeepsAutoStretchEngaged()
    {
        let stretch = Processors.Stretch.STFParameters.uniform( .init( midtones: 0.3 ) )
        let opened  = ImageProcessor.Settings( stretch: stretch )
        let managed = ImageAdjustments( baseline: ImageProcessor.Settings(), opened: opened )

        managed.brightness = 0.3

        #expect( managed.isAutoStretch )
    }

    /// `reset()` returns to the unstretched baseline, so it disengages the managed
    /// mode: after a reset the image is linear and no longer auto-stretched.
    @Test
    @MainActor
    func resetDisengagesAutoStretch()
    {
        let stretch = Processors.Stretch.STFParameters.uniform( .init( midtones: 0.3 ) )
        let opened  = ImageProcessor.Settings( stretch: stretch )
        let managed = ImageAdjustments( baseline: ImageProcessor.Settings(), opened: opened )

        #expect( managed.isAutoStretch )

        managed.reset()

        #expect( managed.isAutoStretch == false )
    }

    /// The per-field reset of the stretch disengages the managed mode (it is a stretch
    /// change), while a per-field reset of an unrelated field leaves it engaged.
    @Test
    @MainActor
    func perFieldResetDisengagesOnlyForStretch()
    {
        let stretch = Processors.Stretch.STFParameters.uniform( .init( midtones: 0.3 ) )
        let opened  = ImageProcessor.Settings( stretch: stretch )

        // Resetting an unrelated field keeps the managed mode.
        let keptManaged = ImageAdjustments( baseline: ImageProcessor.Settings(), opened: opened )

        keptManaged.reset( \.brightness )

        #expect( keptManaged.isAutoStretch )

        // Resetting the stretch itself disengages.
        let disengaged = ImageAdjustments( baseline: ImageProcessor.Settings(), opened: opened )

        disengaged.reset( \.stretch )

        #expect( disengaged.isAutoStretch == false )
    }

    // MARK: - Managed mutual exclusion (STF ↔ white balance)

    /// A uniform `{ normalize, stretch }` a stubbed `deriveAutoStretch` returns for the
    /// `uniform` linking — the single shared mapping that composes with white balance.
    private static let uniformSample = ImageProcessor.Settings( normalize: .identity, stretch: .uniform( .init( midtones: 0.3 ) ) )

    /// A per-channel `{ normalize, stretch }` a stubbed `deriveAutoStretch` returns for
    /// the colour-aware linking — the unlinked mapping that excludes white balance.
    private static let perChannelSample = ImageProcessor.Settings( normalize: .identity, stretch: .perChannel( red: .init( midtones: 0.2 ), green: .init( midtones: 0.3 ), blue: .init( midtones: 0.4 ) ) )

    /// A managed image opened with a per-channel auto STF and no white balance — the
    /// colour-on-open starting state (Appendix row 1).
    @MainActor
    private static func managedPerChannel() -> ImageAdjustments
    {
        let opened      = ImageProcessor.Settings( normalize: .identity, stretch: Self.perChannelSample.stretch )
        let adjustments = ImageAdjustments( baseline: ImageProcessor.Settings(), opened: opened )

        adjustments.deriveAutoStretch = { $0 ? Self.uniformSample : Self.perChannelSample }

        return adjustments
    }

    /// A managed image opened with a uniform auto STF and white balance on — the
    /// starting state for the per-channel-engage collision (Appendix rows 3–5, 8).
    @MainActor
    private static func managedUniformWithWhiteBalance() -> ImageAdjustments
    {
        let opened      = ImageProcessor.Settings( normalize: .identity, stretch: .uniform( .init( midtones: 0.3 ) ), whiteBalance: .auto )
        let adjustments = ImageAdjustments( baseline: ImageProcessor.Settings(), opened: opened )

        adjustments.deriveAutoStretch = { $0 ? Self.uniformSample : Self.perChannelSample }

        return adjustments
    }

    /// Appendix row 2: enabling white balance while a managed per-channel STF is active
    /// makes the STF yield — it is silently re-derived as uniform and white balance stays
    /// on, with managed mode preserved.
    @Test
    @MainActor
    func enablingWhiteBalanceYieldsPerChannelStretchToUniform() async
    {
        let adjustments = Self.managedPerChannel()

        #expect( adjustments.isAutoStretch )

        await adjustments.setWhiteBalance( .auto )

        #expect( adjustments.stretch      == Self.uniformSample.stretch )
        #expect( adjustments.normalize    == Self.uniformSample.normalize )
        #expect( adjustments.whiteBalance == .auto )
        #expect( adjustments.isAutoStretch, "the STF yields silently, staying managed" )
    }

    /// Appendix row 3: engaging a per-channel STF while white balance is active commits
    /// nothing and returns a request; resolving it by removing white balance applies the
    /// per-channel STF, turns white balance off, and stays managed.
    @Test
    @MainActor
    func engagingPerChannelWithWhiteBalanceConfirmsThenRemovesWhiteBalance() async throws
    {
        let adjustments = Self.managedUniformWithWhiteBalance()

        let request = try #require( await adjustments.requestPerChannelAutoStretch() )

        // Nothing committed until the view resolves the confirmation.
        #expect( adjustments.stretch      == .uniform( .init( midtones: 0.3 ) ) )
        #expect( adjustments.whiteBalance == .auto )

        adjustments.resolve( request, as: .removeWhiteBalance )

        #expect( adjustments.stretch      == Self.perChannelSample.stretch )
        #expect( adjustments.whiteBalance == nil )
        #expect( adjustments.isAutoStretch, "the clean exclusive result stays managed" )
    }

    /// Appendix row 4: resolving the same collision by keeping white balance applies the
    /// per-channel STF, leaves white balance on, and drops to manual mode.
    @Test
    @MainActor
    func engagingPerChannelKeepingWhiteBalanceCoexistsAndDropsToManual() async throws
    {
        let adjustments = Self.managedUniformWithWhiteBalance()

        let request = try #require( await adjustments.requestPerChannelAutoStretch() )

        adjustments.resolve( request, as: .keepWhiteBalance )

        #expect( adjustments.stretch      == Self.perChannelSample.stretch )
        #expect( adjustments.whiteBalance == .auto, "white balance is kept" )
        #expect( adjustments.isAutoStretch == false, "coexistence drops to manual" )
    }

    /// Appendix row 5: cancelling the confirmation (discarding the request without
    /// resolving it) leaves everything unchanged.
    @Test
    @MainActor
    func cancellingPerChannelEngageLeavesEverythingUnchanged() async throws
    {
        let adjustments = Self.managedUniformWithWhiteBalance()

        _ = try #require( await adjustments.requestPerChannelAutoStretch() )

        // Cancel: `resolve` is never called and the request is discarded.
        #expect( adjustments.stretch      == .uniform( .init( midtones: 0.3 ) ) )
        #expect( adjustments.whiteBalance == .auto )
        #expect( adjustments.isAutoStretch )
    }

    /// Engaging a per-channel STF when white balance is off is not a collision, so it is
    /// applied and managed mode engaged directly, with no request to resolve.
    @Test
    @MainActor
    func engagingPerChannelWithoutWhiteBalanceAppliesDirectly() async
    {
        let opened      = ImageProcessor.Settings( normalize: .identity, stretch: .uniform( .init( midtones: 0.3 ) ) )
        let adjustments = ImageAdjustments( baseline: ImageProcessor.Settings(), opened: opened )

        adjustments.deriveAutoStretch = { $0 ? Self.uniformSample : Self.perChannelSample }

        let request = await adjustments.requestPerChannelAutoStretch()

        #expect( request == nil, "no white balance to confirm removing" )
        #expect( adjustments.stretch      == Self.perChannelSample.stretch )
        #expect( adjustments.whiteBalance == nil )
        #expect( adjustments.isAutoStretch )
    }

    /// Appendix row 7: in manual mode the exclusion does not apply — enabling white
    /// balance with a per-channel stretch leaves the stretch untouched, and the two
    /// coexist. The re-derivation is never consulted.
    @Test
    @MainActor
    func enablingWhiteBalanceInManualModeLeavesPerChannelStretchUntouched() async
    {
        let perChannel  = Processors.Stretch.STFParameters.perChannel( red: .init( midtones: 0.2 ), green: .init( midtones: 0.3 ), blue: .init( midtones: 0.4 ) )
        let adjustments = ImageAdjustments()

        // A direct write is a manual edit, so this is a hand-built per-channel STF.
        adjustments.stretch           = perChannel
        adjustments.deriveAutoStretch = { _ in Self.uniformSample }

        #expect( adjustments.isAutoStretch == false )

        await adjustments.setWhiteBalance( .auto )

        #expect( adjustments.stretch      == perChannel, "no forcing in manual mode" )
        #expect( adjustments.whiteBalance == .auto )
        #expect( adjustments.isAutoStretch == false )
    }

    /// Appendix row 8: turning white balance off while a managed uniform STF is active
    /// simply removes white balance — the uniform STF is unchanged and stays managed.
    @Test
    @MainActor
    func disablingWhiteBalanceLeavesTheUniformStretchEngaged() async
    {
        let adjustments = Self.managedUniformWithWhiteBalance()

        await adjustments.setWhiteBalance( nil )

        #expect( adjustments.whiteBalance == nil )
        #expect( adjustments.stretch      == .uniform( .init( midtones: 0.3 ) ), "the stretch is untouched" )
        #expect( adjustments.isAutoStretch, "still managed" )
    }

    /// When no derivation is possible the collision cannot be resolved, so the model
    /// commits nothing rather than leaving a per-channel STF and white balance both
    /// active: the per-channel engage returns `nil`, and enabling white balance refuses.
    @Test
    @MainActor
    func noDerivationCommitsNothingAndPreservesTheInvariant() async
    {
        let opened      = ImageProcessor.Settings( normalize: .identity, stretch: Self.perChannelSample.stretch )
        let adjustments = ImageAdjustments( baseline: ImageProcessor.Settings(), opened: opened )

        // `deriveAutoStretch` left at its no-op default, which returns nil.
        let request = await adjustments.requestPerChannelAutoStretch()

        #expect( request == nil )
        #expect( adjustments.stretch == Self.perChannelSample.stretch )

        await adjustments.setWhiteBalance( .auto )

        #expect( adjustments.whiteBalance == nil, "white balance is not enabled without a yield" )
        #expect( adjustments.stretch      == Self.perChannelSample.stretch )
        #expect( adjustments.isAutoStretch )
    }

    /// A derivation that returns a settings value carrying no stretch is not a usable
    /// yield, so enabling white balance must refuse rather than leave a per-channel STF
    /// and white balance both active while managed.
    @Test
    @MainActor
    func enablingWhiteBalanceRefusesWhenTheUniformYieldHasNoStretch() async
    {
        let opened      = ImageProcessor.Settings( normalize: .identity, stretch: Self.perChannelSample.stretch )
        let adjustments = ImageAdjustments( baseline: ImageProcessor.Settings(), opened: opened )

        // Non-nil settings, but with no stretch — the uniform yield cannot be produced.
        adjustments.deriveAutoStretch = { _ in ImageProcessor.Settings( normalize: .identity ) }

        await adjustments.setWhiteBalance( .auto )

        #expect( adjustments.whiteBalance == nil, "no usable yield ⇒ white balance stays off" )
        #expect( adjustments.stretch      == Self.perChannelSample.stretch, "the per-channel STF is untouched" )
        #expect( adjustments.isAutoStretch )
    }

    /// If a concurrent main-actor edit drops to manual while the off-actor uniform derive
    /// is in flight, resuming must not clobber it: the precondition is re-checked after the
    /// await, so the hand-edited stretch is preserved and white balance is simply set.
    @Test
    @MainActor
    func enablingWhiteBalanceDoesNotClobberAConcurrentManualEdit() async
    {
        let adjustments = Self.managedPerChannel()
        let manualEdit  = Processors.Stretch.STFParameters.uniform( .init( midtones: 0.9 ) )

        // The stub stands in for the user hand-editing the stretch mid-derive (a direct
        // write disengages managed mode), then returns the now-stale uniform yield.
        adjustments.deriveAutoStretch =
        { [ weak adjustments ] _ in

            adjustments?.stretch = manualEdit

            return Self.uniformSample
        }

        await adjustments.setWhiteBalance( .auto )

        #expect( adjustments.stretch      == manualEdit, "the concurrent manual edit is preserved" )
        #expect( adjustments.isAutoStretch == false )
        #expect( adjustments.whiteBalance == .auto )
    }

    /// Disengaging the managed mode (the Auto toggle turned off) freezes the current
    /// stretch as a manual value: the stretch and white balance are untouched and only
    /// the managed flag clears, so re-engaging simply re-derives.
    @Test
    @MainActor
    func disengageAutoStretchFreezesTheCurrentStretchAsManual() async
    {
        let adjustments = Self.managedUniformWithWhiteBalance()
        let stretch     = adjustments.stretch
        let whiteBalance = adjustments.whiteBalance

        #expect( adjustments.isAutoStretch )

        adjustments.disengageAutoStretch()

        #expect( adjustments.isAutoStretch == false )
        #expect( adjustments.stretch      == stretch, "the stretch is frozen, not cleared" )
        #expect( adjustments.whiteBalance == whiteBalance, "white balance is untouched" )
    }

    /// The inline-note conditions reflect which control is neutralizing the colour cast
    /// while managed: a managed per-channel stretch (white balance off) reports the stretch
    /// is handling it, a managed uniform stretch with white balance on reports white balance
    /// is handling it, and neither reports true in manual mode or with no managed stretch.
    @Test
    @MainActor
    func colorBalanceHandlingNotesReflectTheManagedState()
    {
        // Managed per-channel, white balance off: the stretch is handling the balance.
        let perChannel = Self.managedPerChannel()

        #expect( perChannel.perChannelStretchHandlesColorBalance )
        #expect( perChannel.whiteBalanceHandlesColorBalance == false )

        // Managed uniform with white balance on: white balance is handling the balance.
        let uniform = Self.managedUniformWithWhiteBalance()

        #expect( uniform.whiteBalanceHandlesColorBalance )
        #expect( uniform.perChannelStretchHandlesColorBalance == false )

        // Manual per-channel (a hand-set stretch): neither note applies — no forcing.
        let manual = ImageAdjustments()

        manual.stretch = .perChannel( red: .init( midtones: 0.2 ), green: .init( midtones: 0.3 ), blue: .init( midtones: 0.4 ) )

        #expect( manual.perChannelStretchHandlesColorBalance == false )
        #expect( manual.whiteBalanceHandlesColorBalance == false )

        // No stretch at all: neither note applies.
        let none = ImageAdjustments()

        #expect( none.perChannelStretchHandlesColorBalance == false )
        #expect( none.whiteBalanceHandlesColorBalance == false )
    }

    /// Engaging a uniform managed stretch (the Screen Transfer editor switching a managed
    /// stretch to uniform) applies the derived uniform STF, engages managed mode, and —
    /// since a uniform stretch composes with white balance — leaves white balance on.
    @Test
    @MainActor
    func engageUniformStretchAppliesUniformAndKeepsWhiteBalance() async
    {
        // A manual per-channel stretch with white balance on.
        let adjustments = ImageAdjustments()

        adjustments.stretch           = .perChannel( red: .init( midtones: 0.2 ), green: .init( midtones: 0.3 ), blue: .init( midtones: 0.4 ) )
        adjustments.whiteBalance      = .auto
        adjustments.deriveAutoStretch = { $0 ? Self.uniformSample : Self.perChannelSample }

        #expect( adjustments.isAutoStretch == false )

        await adjustments.engageUniformStretch()

        #expect( adjustments.stretch      == Self.uniformSample.stretch )
        #expect( adjustments.isAutoStretch, "the uniform stretch is now managed" )
        #expect( adjustments.whiteBalance == .auto, "a uniform stretch composes with white balance" )
    }
}
