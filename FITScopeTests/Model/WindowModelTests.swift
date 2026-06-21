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
import Foundation
import Testing

/// Tests for `WindowModel`: open appends and auto-selects, close removes and
/// keeps a valid selection.
@Suite( "WindowModel" )
struct WindowModelTests
{
    private var corpusURLs: [ URL ]
    {
        [
            FITSCorpus.url( "NASA/FOSy19g0309t_c2f.fits" ),
            FITSCorpus.url( "NASA/FOSy19g0309t_c2f.fits" ),
        ]
    }

    @Test
    @MainActor
    func openAppendsAndSelectsFirstWhenEmpty() throws
    {
        let model = WindowModel()

        model.open( urls: self.corpusURLs )

        #expect( model.files.count == 2 )
        #expect( model.selectedFileID == model.files.first?.id, "opening into an empty window selects the first new file" )
    }

    @Test
    @MainActor
    func openKeepsExistingSelection() throws
    {
        let model = WindowModel()

        model.open( urls: [ self.corpusURLs[ 0 ] ] )

        let firstID = try #require( model.selectedFileID )

        model.open( urls: [ self.corpusURLs[ 1 ] ] )

        #expect( model.files.count == 2 )
        #expect( model.selectedFileID == firstID, "opening more files must not steal an existing selection" )
    }

    @Test
    @MainActor
    func closingSelectedSelectsAnotherFile()  throws
    {
        let model = WindowModel()

        model.open( urls: self.corpusURLs )

        let selected = try #require( model.selectedFile )

        model.close( selected )

        #expect( model.files.count == 1 )
        #expect( model.selectedFileID == model.files.first?.id, "closing the selected file selects a remaining one" )
    }

    @Test
    @MainActor
    func closingLastFileClearsSelection() throws
    {
        let model = WindowModel()

        model.open( urls: [ self.corpusURLs[ 0 ] ] )

        let only = try #require( model.selectedFile )

        model.close( only )

        #expect( model.files.isEmpty )
        #expect( model.selectedFileID == nil )
    }

    @Test
    @MainActor
    func openPreparesEachFile() async throws
    {
        let model = WindowModel()

        model.open( urls: self.corpusURLs )

        for file in model.files
        {
            await file.preparation?.value
        }

        #expect( model.files.isEmpty == false )
        #expect( model.files.allSatisfy { $0.renderPhase == .ready }, "opening a file renders it without waiting to be displayed" )
    }

    @Test
    @MainActor
    func closingAFileCancelsItsPreparation() throws
    {
        let model = WindowModel()

        model.open( urls: [ self.corpusURLs[ 0 ] ] )

        let file = try #require( model.files.first )

        model.close( file )

        #expect( file.preparation?.isCancelled == true, "closing a file cancels its in-flight preparation" )
    }
}

/// Tests for `RenderThrottle`: it bounds how many preparations run at once.
@Suite( "RenderThrottle" )
@MainActor
struct RenderThrottleTests
{
    @Test
    func acquireBeyondTheLimitWaitsForARelease() async throws
    {
        let throttle = RenderThrottle( limit: 1 )

        await throttle.acquire()

        var secondAcquired = false

        let waiter = Task
        { @MainActor in
            await throttle.acquire()
            secondAcquired = true
        }

        // Let the waiter run; with the single slot taken it must block.
        await Task.yield()
        await Task.yield()

        #expect( secondAcquired == false, "a second acquire beyond the limit must wait" )

        throttle.release()
        await waiter.value

        #expect( secondAcquired, "releasing a slot lets a waiter proceed" )
    }

    @Test
    func acquiresUpToTheLimitWithoutWaiting() async throws
    {
        let throttle = RenderThrottle( limit: 2 )

        await throttle.acquire()
        await throttle.acquire()

        // Both acquired without suspending; release so the throttle is balanced.
        throttle.release()
        throttle.release()
    }
}
