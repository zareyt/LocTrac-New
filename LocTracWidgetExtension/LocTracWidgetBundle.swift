//
//  LocTracWidgetBundle.swift
//  LocTrac
//
//  Widget bundle configuration
//

import WidgetKit
import SwiftUI

@main
struct LocTracWidgetBundle: WidgetBundle {
    var body: some Widget {
        LocTracWidget()
        TravelSnapshotWidget()
        ActivityPulseWidget()
        GreenImpactWidget()
        DashboardWidget()
    }
}
