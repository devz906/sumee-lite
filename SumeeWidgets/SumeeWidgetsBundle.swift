//
//  SumeeWidgetsBundle.swift
//  SumeeWidgets
//
//  Created by Getzemani Cruz on 05/02/26.
//

import WidgetKit
import SwiftUI

@main
struct SumeeWidgetsBundle: WidgetBundle {
    var body: some Widget {
        LastPlayedWidget()
        RandomGameWidget()
        SumeeWidgetsControl()
    }
}
