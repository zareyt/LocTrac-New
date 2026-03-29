//
//  DataStore+InfographicsCache.swift
//  LocTrac
//
//  Extension to integrate infographics cache with data operations
//

import Foundation

extension DataStore {
    
    /// Shared cache manager instance
    static let infographicsCache = InfographicsCacheManager()
    
    // MARK: - Cache Invalidation Hooks
    
    /// Invalidate cache when events change
    func invalidateCacheForEvent(_ event: Event, isDelete: Bool = false) {
        Task {
            var tracker = InfographicsChangeTracker()
            tracker.trackEventChange(event, isDelete: isDelete)
            
            let (years, sections) = tracker.getInvalidations()
            await Self.infographicsCache.invalidate(affectedYears: years, sections: sections)
        }
    }
    
    /// Invalidate cache when activities change
    func invalidateCacheForActivity(_ activity: Activity) {
        Task {
            // Find all years where this activity is used
            let affectedYears = events
                .filter { $0.activityIDs.contains(activity.id) }
                .map { Calendar.current.component(.year, from: $0.date) }
            
            var tracker = InfographicsChangeTracker()
            tracker.trackActivityChange(affectedEventYears: affectedYears)
            
            let (years, sections) = tracker.getInvalidations()
            await Self.infographicsCache.invalidate(affectedYears: years, sections: sections)
        }
    }
    
    /// Invalidate cache when locations change
    func invalidateCacheForLocation(_ location: Location) {
        Task {
            // Find all years where this location is used
            let affectedYears = events
                .filter { $0.location.id == location.id }
                .map { Calendar.current.component(.year, from: $0.date) }
            
            var tracker = InfographicsChangeTracker()
            tracker.trackLocationChange(affectedEventYears: affectedYears)
            
            let (years, sections) = tracker.getInvalidations()
            await Self.infographicsCache.invalidate(affectedYears: years, sections: sections)
        }
    }
    
    /// Invalidate cache for specific year
    func invalidateCacheForYear(_ year: Int) {
        Task {
            await Self.infographicsCache.invalidateYear(String(year))
        }
    }
    
    /// Clear all infographics cache
    func clearInfographicsCache() {
        Task {
            await Self.infographicsCache.clearAll()
        }
    }
}

// MARK: - Override Save Methods

extension DataStore {
    
    /// Save with cache invalidation tracking
    func saveWithCacheInvalidation() {
        save()
        // Cache invalidation happens automatically through the add/update/delete methods
    }
}
