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

import CryptoKit
@testable import FITScope
import Foundation
import SwiftPixel
import Testing

/// **Temporary scaffolding — removed in M9.**
///
/// This suite captures, as committed SHA-256 digests, the exact detection image
/// and default render every test input produces through the app's *current*
/// loader path — before any decoding moves into SwiftAstro. It exists for one
/// reason: once the shared decoder lands, there is no way to prove after the fact
/// that the bytes did not change. Freezing them here makes byte-identity a thing
/// the later milestones can check rather than assert.
///
/// It walks every input on both sides of the coming boundary — the synthetic
/// fixtures, the full-frame captures, and the frames already in SwiftAstro's test
/// tree — opens each through the real ``ImageLoader`` exactly as the app does, and
/// for every frame records two digests:
///
/// - the frame's ``ImageRenderSource/detectionImage`` (what star detection and the
///   sky-background measurement consume), and
/// - the bytes of its default ``RenderResultProducing/makeResult(settings:)`` (so
///   rewiring the render onto the decoder is guarded too).
///
/// Entries are keyed by file **name plus frame index**, never by path, so the
/// fixture relocation in M3 leaves the baseline valid: only the files' locations
/// change, not their names.
///
/// The test host is sandboxed and cannot write into the source tree, so the
/// committed baseline is only ever *read* here. When it is present and matches,
/// the suite is green. When it is absent (a bootstrap) or a digest diverges, the
/// suite writes the recomputed digests to its writable temporary directory,
/// records that path, and fails — so the committed file can be created or
/// re-baselined from it deliberately, then re-run to validate. The comparison is
/// over the decoded digest model, not the raw file bytes, so re-serialising the
/// baseline does not affect it.
///
/// - Note: This is deliberately slow: it decodes and renders ~237 MB of captures,
///   a 40 MB CR3 through LibRAW among them. That cost is accepted for the
///   scaffolding's short lifetime.
@MainActor
@Suite( "Detection image golden baseline" )
struct DetectionImageGoldenTests
{
    // MARK: - Committed golden model

    /// The two digests recorded for one frame.
    private struct FrameDigest: Codable, Equatable
    {
        /// The SHA-256 of the frame's detection image, or `nil` when the frame
        /// yields none (a graph / spectrum frame, or a frame whose detection
        /// decode failed). A present entry with a `nil` digest is a real, recorded
        /// outcome — distinct from a frame that is absent entirely.
        let detectionImage: String?

        /// The SHA-256 of the frame's default render bytes, or `nil` when the
        /// frame does not render (a graph, an unsupported geometry, a source whose
        /// extraction failed).
        let render: String?

        /// The keys, held explicitly so `nil` is encoded as an explicit `null`
        /// rather than an omitted key.
        private enum CodingKeys: String, CodingKey
        {
            case detectionImage
            case render
        }

        /// Creates a frame digest.
        ///
        /// - Parameters:
        ///   - detectionImage: The detection-image digest, or `nil`.
        ///   - render:         The render digest, or `nil`.
        init( detectionImage: String?, render: String? )
        {
            self.detectionImage = detectionImage
            self.render         = render
        }

        /// Decodes a frame digest, tolerating either an explicit `null` or an
        /// absent key as `nil`.
        ///
        /// - Parameter decoder: The decoder.
        /// - Throws: Any decoding error.
        init( from decoder: any Decoder ) throws
        {
            let container = try decoder.container( keyedBy: CodingKeys.self )

            self.detectionImage = try container.decodeIfPresent( String.self, forKey: .detectionImage )
            self.render         = try container.decodeIfPresent( String.self, forKey: .render )
        }

        /// Encodes a frame digest, writing an explicit `null` for a `nil` digest so
        /// a frame that legitimately yields none is a recorded sentinel rather than
        /// an absent entry.
        ///
        /// - Parameter encoder: The encoder.
        /// - Throws: Any encoding error.
        func encode( to encoder: any Encoder ) throws
        {
            var container = encoder.container( keyedBy: CodingKeys.self )

            try Self.encode( self.detectionImage, forKey: .detectionImage, into: &container )
            try Self.encode( self.render, forKey: .render, into: &container )
        }

        /// Encodes an optional string as its value or an explicit `null`.
        ///
        /// - Parameters:
        ///   - value:     The value, or `nil`.
        ///   - key:       The key to encode under.
        ///   - container: The container to encode into.
        /// - Throws: Any encoding error.
        private static func encode( _ value: String?, forKey key: CodingKeys, into container: inout KeyedEncodingContainer< CodingKeys > ) throws
        {
            guard let value
            else
            {
                try container.encodeNil( forKey: key )

                return
            }

            try container.encode( value, forKey: key )
        }
    }

    /// Everything recorded for one input file.
    private struct InputDigest: Codable, Equatable
    {
        /// Whether the loader opened the file at all. `false` for a file the app
        /// legitimately rejects (`InvalidImage.fits`), which then yields no frames.
        /// A malformed *spectrum* still opens as a graph frame, so it is recorded
        /// `true` with a single frame that yields neither a detection image nor a
        /// render.
        let opened: Bool

        /// The per-frame digests, in the loader's frame order.
        let frames: [ FrameDigest ]
    }

    /// The committed baseline: input file name → its recorded digests.
    private typealias Golden = [ String: InputDigest ]

    /// The committed baseline file, alongside this source.
    private static let goldenFileName = "detection-image-golden.json"

    // MARK: - The baseline check

    /// Recomputes every input's digests through the real loader path and compares
    /// them to the committed baseline.
    ///
    /// The test host is sandboxed, so it cannot write into the source tree: on a
    /// bootstrap (no committed baseline) or a mismatch it writes the freshly
    /// computed digests to its writable temporary directory instead, and records
    /// the path, so the committed file can be created or re-baselined from it
    /// deliberately. When the baseline is present and matches, nothing is written
    /// and the test is green.
    @Test
    func detectionImagesMatchTheCommittedBaseline() async throws
    {
        let computed = try await Self.computeDigests()
        let goldenURL = Self.goldenURL

        guard FileManager.default.fileExists( atPath: goldenURL.path )
        else
        {
            let output = try Self.writeToTemporary( computed )

            Issue.record( "No committed baseline found. Wrote \( computed.count ) inputs to \( output.path ) — copy it to \( Self.goldenFileName ) alongside this suite and commit it, then re-run to validate." )

            return
        }

        let committed = try Self.read( from: goldenURL )
        let matched   = Self.expectMatch( computed: computed, committed: committed )

        // On any divergence, emit the recomputed digests so a deliberate
        // re-baseline (e.g. the CFA-cube fix in M4) can adopt them after review.
        if matched == false
        {
            let output = try Self.writeToTemporary( computed )

            Issue.record( "Recomputed digests written to \( output.path ) for review; adopt them only as a deliberate, documented re-baseline." )
        }
    }

    // MARK: - Computing the digests

    /// Opens every input through the real ``ImageLoader`` and records each frame's
    /// detection-image and render digests.
    ///
    /// - Returns: The digests, keyed by file name.
    /// - Throws: Only on a programming error building the map; a file that fails to
    ///   open is recorded as `opened: false`, not thrown.
    private static func computeDigests() async throws -> Golden
    {
        var golden = Golden()

        for url in Self.inputURLs
        {
            let name = url.lastPathComponent

            #expect( golden[ name ] == nil, "Two inputs share the file name \( name ); the baseline keys by name and needs them unique." )

            golden[ name ] = await Self.digest( forInputAt: url )
        }

        return golden
    }

    /// Opens one input and records its per-frame digests.
    ///
    /// - Parameter url: The input file.
    /// - Returns: The input's digests.
    private static func digest( forInputAt url: URL ) async -> InputDigest
    {
        let loader = ImageLoader.loader( for: url )

        await loader.load()

        let opened = loader.error == nil

        let frames = loader.frames.map
        {
            frame -> FrameDigest in

            // The source is extracted on the main actor; a per-frame extraction
            // failure (a captured decode error) leaves both digests nil, which is
            // itself a recorded outcome.
            let source = try? frame.renderer.renderSourceSnapshot()

            let detection = source?.detectionImage.map { Self.digest( of: $0 ) }
            let render    = ( try? source?.makeResult( settings: ImageProcessor.Settings() ) ).map { Self.digest( ofRenderBytes: $0.bytes ) }

            return FrameDigest( detectionImage: detection, render: render )
        }

        return InputDigest( opened: opened, frames: frames )
    }

    // MARK: - Digests

    /// Digests a detection image over its geometry and the little-endian bit
    /// patterns of its samples.
    ///
    /// The bit patterns are hashed, not formatted values, so a `NaN` produced by
    /// `BLANK` masking is both distinguishable from a finite value and stable
    /// across runs (its exact bit pattern is preserved). On this platform (always
    /// little-endian) a `[Double]`'s in-memory bytes are exactly those bit
    /// patterns, so they are hashed directly.
    ///
    /// - Parameter buffer: The detection image.
    /// - Returns: The SHA-256, as a lowercase hex string.
    private static func digest( of buffer: PixelBuffer ) -> String
    {
        var hasher = SHA256()

        hasher.update( data: Self.littleEndianBytes( Int64( buffer.width    ) ) )
        hasher.update( data: Self.littleEndianBytes( Int64( buffer.height   ) ) )
        hasher.update( data: Self.littleEndianBytes( Int64( buffer.channels ) ) )

        buffer.pixels.withUnsafeBytes
        {
            hasher.update( bufferPointer: $0 )
        }

        return Self.hex( hasher.finalize() )
    }

    /// Digests a frame's default render bytes.
    ///
    /// - Parameter bytes: The render's 8-bit output bytes.
    /// - Returns: The SHA-256, as a lowercase hex string.
    private static func digest( ofRenderBytes bytes: [ UInt8 ] ) -> String
    {
        Self.hex( SHA256.hash( data: Data( bytes ) ) )
    }

    /// The little-endian byte representation of a 64-bit integer.
    ///
    /// - Parameter value: The value to serialize.
    /// - Returns: Its eight little-endian bytes.
    private static func littleEndianBytes( _ value: Int64 ) -> Data
    {
        var little = value.littleEndian

        return withUnsafeBytes( of: &little ) { Data( $0 ) }
    }

    /// Formats a SHA-256 digest as a lowercase hex string.
    ///
    /// - Parameter digest: The digest.
    /// - Returns: The 64-character hex string.
    private static func hex( _ digest: SHA256.Digest ) -> String
    {
        digest.map { String( format: "%02x", $0 ) }.joined()
    }

    // MARK: - Comparison

    /// Asserts the computed digests match the committed baseline, reporting the
    /// first point of divergence per input rather than one opaque whole-map
    /// mismatch.
    ///
    /// - Parameters:
    ///   - computed:  The freshly computed digests.
    ///   - committed: The committed baseline.
    /// - Returns: `true` when every input matched, `false` when any diverged.
    @discardableResult
    private static func expectMatch( computed: Golden, committed: Golden ) -> Bool
    {
        let names = Set( computed.keys ).union( committed.keys ).sorted()

        return names.reduce( true )
        {
            matched, name in

            guard let expected = committed[ name ]
            else
            {
                Issue.record( "Input \( name ) is new — not in the committed baseline. Re-baseline deliberately if this is intended." )

                return false
            }

            guard let actual = computed[ name ]
            else
            {
                Issue.record( "Input \( name ) is in the baseline but was not found on disk this run." )

                return false
            }

            let openedMatches = actual.opened == expected.opened
            let countMatches  = actual.frames.count == expected.frames.count

            #expect( openedMatches, "\( name ): opened flag changed (\( expected.opened ) → \( actual.opened ))." )
            #expect( countMatches, "\( name ): frame count changed (\( expected.frames.count ) → \( actual.frames.count ))." )

            let framesMatch = zip( actual.frames, expected.frames ).enumerated().reduce( true )
            {
                allMatch, entry in

                let ( index, ( got, want ) ) = entry
                let detectionMatches         = got.detectionImage == want.detectionImage
                let renderMatches            = got.render == want.render

                #expect( detectionMatches, "\( name ) frame \( index ): detection-image digest changed." )
                #expect( renderMatches, "\( name ) frame \( index ): render digest changed." )

                return allMatch && detectionMatches && renderMatches
            }

            return matched && openedMatches && countMatches && framesMatch
        }
    }

    // MARK: - Baseline file I/O

    /// The committed baseline's URL, alongside this source file.
    private static var goldenURL: URL
    {
        URL( fileURLWithPath: #filePath )
            .deletingLastPathComponent()
            .appendingPathComponent( Self.goldenFileName )
    }

    /// Encodes the digests with sorted keys and pretty printing — so the committed
    /// file is stable and reviewable — and writes them to the sandbox-writable
    /// temporary directory, whence they can be copied into the source tree.
    ///
    /// - Parameter golden: The digests to write.
    /// - Returns: The URL written to.
    /// - Throws: Any encoding or write error.
    private static func writeToTemporary( _ golden: Golden ) throws -> URL
    {
        let encoder = JSONEncoder()

        encoder.outputFormatting = [ .prettyPrinted, .sortedKeys ]

        let data = try encoder.encode( golden )
        let url  = FileManager.default.temporaryDirectory.appendingPathComponent( Self.goldenFileName )

        try data.write( to: url )

        return url
    }

    /// Reads and decodes the committed baseline.
    ///
    /// - Parameter url: The baseline file.
    /// - Returns: The decoded digests.
    /// - Throws: Any read or decoding error.
    private static func read( from url: URL ) throws -> Golden
    {
        let data = try Data( contentsOf: url )

        return try JSONDecoder().decode( Golden.self, from: data )
    }

    // MARK: - Inputs

    /// Every input the baseline covers, resolved from both `Test Files/` trees so
    /// the set is invariant under M3's relocation: a file found under the app tree
    /// today and under SwiftAstro's tree after M3 is the same entry, keyed by its
    /// unchanged name.
    private static var inputURLs: [ URL ]
    {
        let extensions: Set< String > = [ "fits", "fit", "xisf", "cr3", "jpg", "jpeg", "png", "tiff", "heic", "heif" ]

        return Self.testFilesRoots.flatMap
        {
            root -> [ URL ] in

            let enumerator = FileManager.default.enumerator( at: root, includingPropertiesForKeys: nil )

            let all = enumerator?.compactMap { $0 as? URL } ?? []

            return all.filter { extensions.contains( $0.pathExtension.lowercased() ) }
        }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    /// The two roots holding the inputs: the app's `Test Files/` and SwiftAstro's.
    private static var testFilesRoots: [ URL ]
    {
        let repoRoot = URL( fileURLWithPath: #filePath )
            .deletingLastPathComponent() // FITScopeTests/Golden/
            .deletingLastPathComponent() // FITScopeTests/
            .deletingLastPathComponent() // repo root

        return
            [
                repoRoot.appendingPathComponent( "Test Files" ),
                repoRoot.appendingPathComponent( "Submodules/SwiftAstro/Test Files" ),
            ]
    }
}
