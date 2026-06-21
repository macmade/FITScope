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

import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// The Information Panel tab of the Preferences window: a checklist of the
/// fields shown in the sidebar's Image Information panel, which the user can
/// toggle on or off and drag — by the trailing handle — to reorder.
///
/// The rows are bound to the shared ``Preferences/infoPanelFields`` config, so
/// toggling or reordering here updates every open window's information panel
/// live and persists across launches. Dragging is driven by an explicit handle
/// on the trailing edge so it never competes with the row's checkbox.
public struct InformationPanelPreferencesView: View
{
    /// The shared, persisted preferences.
    @ObservedObject private var preferences: Preferences

    /// The field currently being dragged, or `nil` when no drag is in progress.
    /// Set when a drag starts and used by the drop delegate to relocate rows.
    @State private var dragging: InfoField?

    /// Creates the Information Panel tab.
    ///
    /// - Parameter preferences: The shared, persisted preferences store. Passed
    ///   in explicitly rather than read from the environment, because a `Settings`
    ///   scene's `TabView` does not reliably propagate environment objects across
    ///   the tab boundary.
    public init( preferences: Preferences )
    {
        self._preferences = ObservedObject( wrappedValue: preferences )
    }

    /// The view's content.
    public var body: some View
    {
        VStack( alignment: .leading, spacing: 0 )
        {
            Text( "Choose which values appear in the Image Information panel, and drag the handles to reorder them." )
                .font( .callout )
                .foregroundStyle( .secondary )
                .fixedSize( horizontal: false, vertical: true )
                .padding( .horizontal, 20 )
                .padding( .top, 18 )
                .padding( .bottom, 12 )

            self.fieldList
                .padding( .horizontal, 20 )

            HStack
            {
                Spacer()

                Button( "Restore Defaults" )
                {
                    self.preferences.resetInfoPanelFields()
                }
                .accessibilityIdentifier( AccessibilityIdentifier.PreferencesView.informationPanelResetButton )
            }
            .padding( .horizontal, 20 )
            .padding( .top, 12 )
            .padding( .bottom, 20 )
        }
        .frame( maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading )
        .accessibilityIdentifier( AccessibilityIdentifier.PreferencesView.informationPanelTab )
    }

    /// The bordered, scrollable list of reorderable field rows.
    private var fieldList: some View
    {
        ScrollView
        {
            VStack( spacing: 0 )
            {
                ForEach( Array( self.preferences.infoPanelFields.enumerated() ), id: \.element.field )
                {
                    index, setting in

                    if index > 0
                    {
                        Divider()
                    }

                    self.row( for: setting.field, isEven: index.isMultiple( of: 2 ) )
                }
            }
        }
        .background( Color( nsColor: .textBackgroundColor ) )
        .clipShape( RoundedRectangle( cornerRadius: 6 ) )
        .overlay
        {
            RoundedRectangle( cornerRadius: 6 ).strokeBorder( Color( nsColor: .separatorColor ) )
        }
        .accessibilityIdentifier( AccessibilityIdentifier.PreferencesView.informationPanelFieldList )
    }

    /// A single field row: a checkbox, the field's label, and a trailing drag
    /// handle that is the sole drag source for reordering.
    ///
    /// - Parameters:
    ///   - field:  The field this row controls.
    ///   - isEven: Whether the row is at an even index, for the alternating
    ///     background tint.
    private func row( for field: InfoField, isEven: Bool ) -> some View
    {
        HStack( spacing: 10 )
        {
            Toggle( isOn: self.isVisibleBinding( for: field ) )
            {
                Label( field.label, systemImage: field.systemImageName )
            }
            .toggleStyle( .checkbox )

            Spacer( minLength: 0 )

            Image( systemName: "line.3.horizontal" )
                .font( .system( size: 13, weight: .semibold ) )
                .foregroundStyle( .tertiary )
                .contentShape( Rectangle() )
                .onHover { $0 ? NSCursor.openHand.push() : NSCursor.pop() }
                .help( "Drag to reorder" )
                .onDrag
                {
                    self.dragging = field

                    return NSItemProvider( object: field.rawValue as NSString )
                }
        }
        .padding( .horizontal, 12 )
        .padding( .vertical, 7 )
        .background( isEven ? Color.clear : Color.primary.opacity( 0.04 ) )
        .opacity( self.dragging == field ? 0.4 : 1 )
        .onDrop(
            of:       [ .text ],
            delegate: FieldReorderDropDelegate( target: field, fields: self.$preferences.infoPanelFields, dragging: self.$dragging )
        )
    }

    /// A binding to a field's visibility that locates the field by identity, so
    /// it stays correct while rows are being reordered.
    ///
    /// - Parameter field: The field whose visibility to bind.
    private func isVisibleBinding( for field: InfoField ) -> Binding< Bool >
    {
        Binding(
            get: { self.preferences.infoPanelFields.first { $0.field == field }?.isVisible ?? false },
            set:
            {
                newValue in

                if let index = self.preferences.infoPanelFields.firstIndex( where: { $0.field == field } )
                {
                    self.preferences.infoPanelFields[ index ].isVisible = newValue
                }
            }
        )
    }
}

/// Relocates the dragged field to a target row's position as the pointer moves
/// over it, giving live reordering driven by the trailing handle.
private struct FieldReorderDropDelegate: DropDelegate
{
    /// The field of the row this delegate is attached to — the drop target.
    let target: InfoField

    /// The shared configuration being reordered.
    @Binding var fields: [ InfoPanelFieldSetting ]

    /// The field currently being dragged.
    @Binding var dragging: InfoField?

    /// Moves the dragged field to the target's index when the pointer enters the
    /// target row.
    func dropEntered( info: DropInfo )
    {
        guard let dragging, dragging != self.target,
              let from = self.fields.firstIndex( where: { $0.field == dragging } ),
              let to   = self.fields.firstIndex( where: { $0.field == self.target } )
        else
        {
            return
        }

        withAnimation
        {
            self.fields.move( fromOffsets: IndexSet( integer: from ), toOffset: to > from ? to + 1 : to )
        }
    }

    /// Reports a move operation so the drag shows the move cursor.
    func dropUpdated( info: DropInfo ) -> DropProposal?
    {
        DropProposal( operation: .move )
    }

    /// Ends the drag, clearing the dragged-field state.
    func performDrop( info: DropInfo ) -> Bool
    {
        self.dragging = nil

        return true
    }
}

#Preview
{
    InformationPanelPreferencesView( preferences: Preferences() )
        .frame( width: 480, height: 360 )
}
