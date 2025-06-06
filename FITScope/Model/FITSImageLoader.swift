/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2025, Jean-David Gadina - www.xs-labs.com
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
import SwiftFITS
import SwiftUI
import SwiftUtilities

@MainActor
public class FITSImageLoader: ObservableObject
{
    @Published public private( set ) var image: FITSImage?
    @Published public private( set ) var error: Error?

    private let url:           URL
    private let document:      FITSDocument
    private var imageObserver: AnyCancellable?

    public init( url: URL, document: FITSDocument )
    {
        self.url      = url
        self.document = document
        self.image    = nil
    }

    public func load() async
    {
        do
        {
            let result = try await withCheckedThrowingContinuation
            {
                continuation in DispatchQueue.global( qos: .userInitiated ).async
                {
                    do
                    {
                        let file = try FITSFile( data: self.document.data )
                        let info = FITSImageInfo( url: self.url, file: file )

                        continuation.resume( returning: ( file: file, info: info ) )
                    }
                    catch
                    {
                        continuation.resume( throwing: error )
                    }
                }
            }

            await MainActor.run
            {
                let renderer       = FITSImageRenderer( file: result.file )
                let image          = FITSImage( file: result.file, info: result.info, renderer: renderer )
                self.image         = image
                self.error         = nil
                self.imageObserver = image.objectWillChange.sink
                {
                    [ weak self ] _ in self?.objectWillChange.send()
                }
            }
        }
        catch
        {
            self.image         = nil
            self.error         = error
            self.imageObserver = nil
        }
    }
}
