//
//  FoodTimelineDetails.swift
//  pods
//
//  Created by Dimi Nunez on 1/20/26.
//


import SwiftUI

// MARK: - FoodTimelineDetails

struct FoodTimelineDetails: View {
    let details: TimelineEvent.Details

    var body: some View {
        HStack(spacing: 12) {
            if let calories = details.calories {
                label(icon: "flame.fill", text: "\(calories) cal", color: Color("brightOrange"))
            }
            if let protein = details.protein {
                macroLabel(prefix: "P", value: protein)
            }
            if let fat = details.fat {
                macroLabel(prefix: "F", value: fat)
            }
            if let carbs = details.carbs {
                macroLabel(prefix: "C", value: carbs)
            }
        }
        .font(.system(size: 13))
        .foregroundColor(.secondary)
    }

    private func label(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(color)
            Text(text)
        }
    }

    private func macroLabel(prefix: String, value: Int) -> some View {
        HStack(spacing: 2) {
            Text(prefix)
                .foregroundColor(.secondary)
            Text("\(value)g")
        }
    }
}

// MARK: - WorkoutTimelineDetails

struct WorkoutTimelineDetails: View {
    let details: TimelineEvent.Details

    var body: some View {
        HStack(spacing: 12) {
            if let calories = details.calories {
                detail(icon: "flame.fill", text: "\(calories) cal")
            }
            if let duration = details.durationMinutes {
                detail(icon: "clock", text: "\(duration) min")
            }
            if let exercises = details.exercises {
                detail(icon: "list.bullet", text: "\(exercises) exercises")
            }
        }
        .font(.system(size: 13))
        .foregroundColor(.secondary)
    }

    private func detail(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            Text(text)
        }
    }
}

// MARK: - CardioTimelineDetails

struct CardioTimelineDetails: View {
    let details: TimelineEvent.Details

    var body: some View {
        HStack(spacing: 12) {
            if let calories = details.calories {
                detail(icon: "flame.fill", text: "\(calories) cal")
            }
            if let duration = details.durationMinutes {
                detail(icon: "clock", text: "\(duration) min")
            }
            if let distance = details.distanceMiles {
                detail(icon: "mappin.and.ellipse", text: String(format: "%.2f mi", distance))
            }
        }
        .font(.system(size: 13))
        .foregroundColor(.secondary)
    }

    private func detail(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            Text(text)
        }
    }
}

// MARK: - WakeTimelineDetails

struct WakeTimelineDetails: View {
    let details: TimelineEvent.Details

    var body: some View {
        HStack(spacing: 12) {
            if let duration = details.sleepDurationText {
                detail(icon: "bed.double.fill", text: duration)
            }
            if let readiness = details.readinessScore {
                detail(icon: "leaf.fill", text: "Readiness \(readiness)")
            }
            if let quality = details.sleepQuality {
                detail(icon: "moon.fill", text: "Sleep \(quality)")
            }
        }
        .font(.system(size: 13))
        .foregroundColor(.secondary)
    }

    private func detail(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            Text(text)
        }
    }
}
