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

import SwiftUI

/// The Moon tab's content: the capture's lunar phase — a drawn moon disc, the
/// phase name, the illuminated fraction and the capture date, computed locally —
/// or, when the image carries no date, a "No Date" placeholder.
///
/// It owns both states so its host doesn't branch on the data.
public struct MoonPhaseView: View
{
    /// The capture date the phase is computed for and shown, or `nil` when the
    /// image has no date.
    private let date: Date?

    /// Creates the moon-phase view.
    ///
    /// - Parameter date: The capture date (e.g. a frame's `DATE-OBS`), or `nil`.
    public init( date: Date? )
    {
        self.date = date
    }

    /// The view's content: the phase when a date is known, otherwise a
    /// placeholder. Both fill a bordered card so the tab keeps a stable shape.
    public var body: some View
    {
        Group
        {
            if let date = self.date
            {
                self.phase( for: date )
            }
            else
            {
                StatusMessageView( systemImage: "calendar", title: "No Date", message: "This image has no capture date." )
            }
        }
        .frame( maxWidth: .infinity, maxHeight: .infinity )
        .clipShape( RoundedRectangle( cornerRadius: 10 ) )
        .overlay( RoundedRectangle( cornerRadius: 10 ).strokeBorder( .white.opacity( 0.08 ), lineWidth: 1 ) )
    }

    /// The lunar phase for a date: the disc, the phase name, the illumination and
    /// the date.
    ///
    /// - Parameter date: The capture date.
    private func phase( for date: Date ) -> some View
    {
        let moonPhase = MoonPhase( date: date )

        return VStack( spacing: 8 )
        {
            MoonPhaseDisc( fraction: moonPhase.fraction )
                .frame( width: 92, height: 92 )
                .accessibilityIdentifier( AccessibilityIdentifier.MoonPhaseView.icon )

            Text( moonPhase.phase.name )
                .font( .system( size: 12, weight: .semibold ) )

            Text( Self.illuminationText( moonPhase ) )
                .font( .system( size: 10 ) )
                .foregroundStyle( .secondary )

            Text( Self.dateText( date ) )
                .font( .system( size: 10 ) )
                .foregroundStyle( .tertiary )
        }
        .padding( 12 )
        .frame( maxWidth: .infinity, maxHeight: .infinity )
        .background( .regularMaterial )
        // Let the phase name, illumination and date be selected and copied,
        // matching the Image Information panel.
        .textSelection( .enabled )
    }

    /// The illuminated fraction as a whole-percent sentence, e.g.
    /// `73% illuminated`.
    ///
    /// - Parameter moonPhase: The phase to describe.
    private static func illuminationText( _ moonPhase: MoonPhase ) -> String
    {
        let percent = Int( ( moonPhase.illumination * 100 ).rounded() )

        return "\( percent )% illuminated"
    }

    /// A date formatted in UTC (the time zone `DATE-OBS` is recorded in), e.g.
    /// `2024-01-25 17:54 UTC`.
    ///
    /// - Parameter date: The date to format.
    private static func dateText( _ date: Date ) -> String
    {
        let formatter        = DateFormatter()
        formatter.locale     = Locale( identifier: "en_US_POSIX" )
        formatter.timeZone   = TimeZone( identifier: "UTC" )
        formatter.dateFormat = "yyyy-MM-dd HH:mm 'UTC'"

        return formatter.string( from: date )
    }
}

#Preview
{
    MoonPhaseView( date: Date( timeIntervalSince1970: 1_706_204_040 ) )
        .frame( width: 260, height: 200 )
}
