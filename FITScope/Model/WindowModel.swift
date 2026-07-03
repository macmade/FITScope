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

import Combine
import Foundation
import SwiftUI

/// The state of a single window: the ordered list of open files and the current
/// selection. Each window owns one instance; windows are fully independent.
@MainActor
public final class WindowModel: ObservableObject
{
    /// The open files, in the order they were opened.
    @Published public private( set ) var files: [ OpenFile ] = []

    /// The id of the currently selected file, or `nil` when none is selected.
    @Published public var selectedFileID: OpenFile.ID?

    /// The key the sidebar list is sorted by. The files keep their opened order
    /// internally; ``sortedFiles`` derives the displayed order from this key.
    @Published public var sortKey: FileSortKey = .opened

    /// Called with a file's identifier right after it is closed, so the window's
    /// host can tear down anything keyed to that file — dismissing its plate-solve
    /// results window and ending its solve. Set by the hosting view, since the
    /// dismiss action lives in SwiftUI's environment. Not observed, so setting it
    /// never triggers a view update.
    public var onFileClosed: ( ( OpenFile.ID ) -> Void )?

    /// Whether the sort is ascending (smallest / A-first) or descending.
    @Published public var sortAscending = true

    /// The source text of the formula used to weight the open files against one
    /// another. Defaults to the built-in expression; the UI keeps it in step with
    /// the user's preference. Changing it recomputes every file's weight.
    public var weightFormulaSource = WeightFormula.defaultExpression
    {
        didSet
        {
            guard self.weightFormulaSource != oldValue
            else
            {
                return
            }

            self.scheduleWeightRecompute()
        }
    }

    /// Bounds how many files render at once, so opening many files cannot
    /// saturate the CPU or spike memory. Shared by every file in the window.
    private let renderThrottle = RenderThrottle( limit: max( 2, ProcessInfo.processInfo.activeProcessorCount - 2 ) )

    /// Per-file change subscriptions, so the window recomputes weights when a
    /// file finishes analysis (its metrics arrive asynchronously). Rebuilt
    /// whenever the file set changes.
    private var fileObservers: [ AnyCancellable ] = []

    /// Whether a weight recomputation is already queued for the next runloop turn,
    /// coalescing the many change notifications a load/render pass emits into a
    /// single recompute.
    private var isWeightRecomputeScheduled = false

    /// Creates an empty window model.
    public init()
    {}

    /// The currently selected open file, or `nil`.
    public var selectedFile: OpenFile?
    {
        self.files.first { $0.id == self.selectedFileID }
    }

    /// The open files in the order the sidebar should display them, derived from
    /// ``sortKey`` and ``sortAscending``. Recomputed on demand, so it reflects
    /// metrics and weights as they arrive asynchronously after a file loads.
    public var sortedFiles: [ OpenFile ]
    {
        self.sortKey.sorted( self.files, ascending: self.sortAscending )
    }

    /// Whether any open file has adjustments that differ from its as-captured
    /// defaults — so closing the window would discard edited images.
    ///
    /// Reuses each file's ``ImageAdjustments/hasAdjustments`` (the single source of
    /// truth for "edited", shared with the sidebar marker) rather than tracking a
    /// separate flag. A file whose image has not loaded yet contributes `false`.
    public var hasAdjustedFiles: Bool
    {
        self.files.contains { $0.hasAdjustments }
    }

    /// Opens the given URLs, appending one ``OpenFile`` per URL. If nothing was
    /// selected, the first newly opened file becomes the selection; an existing
    /// selection is preserved.
    ///
    /// - Parameter urls: The file URLs to open.
    public func open( urls: [ URL ] )
    {
        let newFiles = urls.map { OpenFile( url: $0 ) }

        guard newFiles.isEmpty == false
        else
        {
            return
        }

        self.files.append( contentsOf: newFiles )

        // Render every opened file (not just the displayed one) so its sidebar
        // row updates on its own; the throttle bounds how many run at once.
        newFiles.forEach { $0.prepare( throttle: self.renderThrottle ) }

        if self.selectedFileID == nil
        {
            self.selectedFileID = newFiles.first?.id
        }

        self.observeFilesForWeighting()
        self.scheduleWeightRecompute()
    }

    /// Closes the given file. If it was selected, selection moves to the nearest
    /// remaining file (preferring the previous one), or to `nil` when none
    /// remain.
    ///
    /// - Parameter file: The file to close.
    public func close( _ file: OpenFile )
    {
        guard let index = self.files.firstIndex( where: { $0.id == file.id } )
        else
        {
            return
        }

        let wasSelected = self.selectedFileID == file.id

        file.cancelPreparation()

        self.files.remove( at: index )

        if wasSelected
        {
            let fallback = self.files[ safe: index ] ?? self.files[ safe: index - 1 ] ?? self.files.first

            self.selectedFileID = fallback?.id
        }

        self.observeFilesForWeighting()
        self.scheduleWeightRecompute()

        // The single choke point for closing a file (``trash(_:)`` funnels through
        // here too), so the host tears down the file's plate-solve window and solve
        // whichever way it was closed.
        self.onFileClosed?( file.id )
    }

    /// Moves the given file to the Trash and closes it.
    ///
    /// The entry is removed from the window only if trashing succeeds; a failure
    /// (e.g. a permissions error) propagates so the caller can report it and the
    /// file stays in the list, still pointing at its on-disk source.
    ///
    /// - Parameter file: The file to trash.
    /// - Throws: Any error thrown by `FileManager.trashItem(at:resultingItemURL:)`.
    public func trash( _ file: OpenFile ) throws
    {
        try FileManager.default.trashItem( at: file.url, resultingItemURL: nil )

        self.close( file )
    }

    /// Subscribes to every open file's change notifications, so a file finishing
    /// its analysis (or any change that affects its metrics) triggers a weight
    /// recompute. Replaces any previous subscriptions.
    private func observeFilesForWeighting()
    {
        self.fileObservers = self.files.map
        {
            file in

            file.objectWillChange.sink
            {
                [ weak self ] _ in self?.scheduleWeightRecompute()
            }
        }
    }

    /// Queues a single weight recompute for the next runloop turn, coalescing the
    /// burst of notifications a load/render/analysis pass emits.
    private func scheduleWeightRecompute()
    {
        guard self.isWeightRecomputeScheduled == false
        else
        {
            return
        }

        self.isWeightRecomputeScheduled = true

        Task
        {
            @MainActor [ weak self ] in

            self?.isWeightRecomputeScheduled = false
            self?.recomputeWeights()
        }
    }

    /// Recomputes every open file's weight from its metrics and the current
    /// formula, ranking the files against one another.
    ///
    /// A file whose weight is unchanged is left untouched, so the recompute
    /// settles rather than feeding back on itself through the change observers. An
    /// invalid formula clears every weight.
    func recomputeWeights()
    {
        let metrics = self.files.map { $0.metrics }
        let weights: [ Double? ]

        if let formula = try? WeightFormula( source: self.weightFormulaSource )
        {
            weights = ImageWeighting.weights( for: metrics, using: formula )
        }
        else
        {
            weights = self.files.map { _ in nil }
        }

        zip( self.files, weights ).forEach
        {
            file, weight in

            if file.weight != weight
            {
                file.weight = weight
            }
        }
    }
}
