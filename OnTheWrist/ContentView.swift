//
//  ContentView.swift
//  OnTheWrist
//
//  Created by David Smith on 4/24/20.
//  Copyright © 2020 Cross Forward Consulting, LLC. All rights reserved.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var checker = WristCheck.shared
    var body: some View {
        VStack {
            Text(checker.status)

            Button(action: {
                self.checker.load()
            }) {
                Text("Load")
            }
        }.onAppear() {
            self.checker.load()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

import HealthKit
class WristCheck: ObservableObject {
    static let shared = WristCheck()
    
    let store = HKHealthStore()
    
    @Published var status:String = ""
    
    func updateStatus(_ string:String) {
        DispatchQueue.main.async {
            self.status = string
        }
    }
    
    func load() {
        self.updateStatus("Authorizing...")
        let type = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        store.requestAuthorization(toShare: nil, read: Set(arrayLiteral: type)) { (success, error) in
            print("Authorization Complete", success, error ?? "")
            
            let dateString = "2015-04-24" // change to your date format
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let startDate = dateFormatter.date(from: dateString)!
            let endDate = Date()
            
            var interval = DateComponents()
            interval.hour = 1
            
            let query = HKStatisticsCollectionQuery(
                quantityType: type,
                quantitySamplePredicate: nil,
                options: .discreteAverage,
                anchorDate: startDate,
                intervalComponents: interval)
            
            let possible = endDate.timeIntervalSince(startDate) / 60 / 60
            var count:Int = 0
            
            var hours:[Int:(worn:Int, total:Int)] = [:]
            var days :[String:(worn:Int, total:Int)] = [:]

            self.updateStatus("Starting Query")

            query.initialResultsHandler = { (query, results, error) in
                self.updateStatus("Processing Query")

                let calendar = Calendar.current
                
                if let data = results {
                    data.enumerateStatistics(from: startDate, to: endDate) { (result, stop) in
                        var exists:Bool = false
                        
                        let components = calendar.dateComponents([.hour, .day, .month, .year], from: result.startDate)
                        let hourKey = components.hour!
                        let dayKey  = "\(components.year!)-\(String(format: "%02d", components.month!))-\(String(format: "%02d", components.day!))"
                        let unit = HKUnit.count().unitDivided(by: HKUnit.minute())
                        if let value = result.averageQuantity() {
                            if value.doubleValue(for: unit) > 0 {
                                count += 1
                                exists = true
                            }
                        }
                        
                        if let existingHour = hours[hourKey] {
                            let new = (worn:existingHour.worn + (exists ? 1 : 0), total: existingHour.total + 1)
                            hours[hourKey] = new
                        } else {
                            hours[hourKey] = (worn:1, total:1)
                        }
                        
                        if let existingDay = days[dayKey] {
                            let new = (worn:existingDay.worn + (exists ? 1 : 0), total: existingDay.total + 1)
                            days[dayKey] = new
                        } else {
                            days[dayKey] = (worn:1, total:1)
                        }
                        
                    }

                    print("Hourly Data")
                    for hour in 0...23 {
                        if let value = hours[hour] {
                            let percent = (Double(value.worn) / Double(value.total) * 100.0).rounded()
                            print("\(hour)\t\(percent)")
                        }
                    }

                    print("Daily Data")
                    for key in days.keys.sorted() {
                        if let value = days[key] {
                            let percent = (Double(value.worn) / Double(value.total) * 100).rounded()
                            print("\(key)\t\(percent)\t\(value.worn)\t\(value.total)")
                        }
                    }
                    let percent = (Double(count) / Double(possible) * 100.0).rounded()
                    self.updateStatus("Complete: \(percent)")
                    
                    print(possible, count, percent)
                }
                
            }
            self.store.execute(query)
        }
    }
    
}

