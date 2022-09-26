//
//  TripController.swift
//  
//
//  Created by Kevin Bertrand on 01/07/2022.
//

import Fluent
import Vapor

struct TripController: RouteCollection {
    // MARK: Properties
    var addressController: AddressController
    
    // MARK: Route initialisation
    func boot(routes: RoutesBuilder) throws {
        let tripGroup = routes.grouped("trip")
        let tokenGroup = tripGroup.grouped(UserToken.authenticator()).grouped(UserToken.guardMiddleware())
        tokenGroup.post(use: add)
        tokenGroup.post("toExport", use: getToExport)
        tokenGroup.patch(use: update)
        tokenGroup.get(":userID", use: getList)
        tokenGroup.get("latest", ":userID", use: getThreeLatests)
        tokenGroup.get("chart", ":filter", ":userID", use: getChartPoint)
        tokenGroup.get("news", ":userID", use: getNews)
    }
    
    // MARK: Routes functions
    /// Add a new trip for a user
    private func add(req: Request) async throws -> Response {
        let userAuth = try getUserAuthFor(req)
        let receivedData = try req.content.decode(Trip.Update.self)
        
        guard let userId = userAuth.id,
              let startingAddressId = try await addressController.create(receivedData.startingAddress, for: req)?.id,
              let endingAddressId = try await addressController.create(receivedData.endingAddress, for: req)?.id  else {
            throw Abort(.unauthorized)
        }
        
        let newTrip = Trip(date: receivedData.date,
                           missions: receivedData.missions,
                           comment: receivedData.comment,
                           totalDistance: receivedData.totalDistance,
                           userID: userId,
                           startingAddressID: startingAddressId,
                           endingAddressID: endingAddressId)
        
        try await newTrip.save(on: req.db)
        
        return .init(status: .ok, headers: getDefaultHttpHeader(), body: .empty)
    }
    
    /// Update a saved trip
    private func update(req: Request) async throws -> Response {
        let userAuth = try getUserAuthFor(req)
        let receivedData = try req.content.decode(Trip.Update.self)
        
        guard let _ = userAuth.id,
              let startingAddressId = try await addressController.create(receivedData.startingAddress, for: req)?.id,
              let endingAddressId = try await addressController.create(receivedData.endingAddress, for: req)?.id,
              receivedData.id != UUID(uuidString: "00000000-0000-0000-0000-000000000000") else {
            throw Abort(.unauthorized)
        }
        
        try await Trip.query(on: req.db)
            .filter(\.$id == receivedData.id)
            .set(\.$date, to: receivedData.date)
            .set(\.$missions, to: receivedData.missions)
            .set(\.$totalDistance, to: receivedData.totalDistance)
            .set(\.$startingAddress.$id, to: startingAddressId)
            .set(\.$endingAddress.$id, to: endingAddressId)
            .set(\.$comment, to: receivedData.comment)
            .update()
        
        return .init(status: .ok, headers: getDefaultHttpHeader(), body: .empty)
    }
    
    /// Get the trip list for a user
    private func getList(req: Request) async throws -> Response {
        let userAuth = try getUserAuthFor(req)
        
        guard let userId = UUID(uuidString: req.parameters.get("userID") ?? "nul ") else {
            throw Abort(.notFound)
        }
        
        guard userAuth.position == .administrator || userAuth.id == userId else {
            throw Abort(.unauthorized)
        }
        
        let trips = try await Trip.query(on: req.db)
            .filter(\.$user.$id == userId)
            .all()
        
        var tripsInformation: [Trip.Informations] = []
        
        for trip in trips {
            let startingAddress = try await addressController.getAddressFromId(trip.$startingAddress.id, for: req)
            let endingAddress = try await addressController.getAddressFromId(trip.$endingAddress.id, for: req)
            
            tripsInformation.append(Trip.Informations(id: trip.id,
                                                      date: trip.date,
                                                      missions: trip.missions,
                                                      comment: trip.comment,
                                                      totalDistance: trip.totalDistance,
                                                      startingAddress: startingAddress,
                                                      endingAddress: endingAddress))
            
        }
        
        return .init(status: .ok, headers: getDefaultHttpHeader(), body: .init(data: try JSONEncoder().encode(tripsInformation)))
    }
    
    /// Getting 3 latests trips
    private func getThreeLatests(req: Request) async throws -> Response {
        guard let userId = UUID(uuidString: req.parameters.get("userID") ?? "nul ") else {
            throw Abort(.notFound)
        }
        
        var trips = try await Trip.query(on: req.db)
            .filter(\.$user.$id == userId)
            .all()
        
        trips = trips.sorted { $0.date > $1.date }
        
        if trips.count > 3 {
            trips = Array(trips[0...2])
        }
        
        var tripsInformation: [Trip.Informations] = []
        
        for trip in trips {
            let startingAddress = try await addressController.getAddressFromId(trip.$startingAddress.id, for: req)
            let endingAddress = try await addressController.getAddressFromId(trip.$endingAddress.id, for: req)
            
            tripsInformation.append(Trip.Informations(id: trip.id,
                                                      date: trip.date,
                                                      missions: trip.missions,
                                                      comment: trip.comment,
                                                      totalDistance: trip.totalDistance,
                                                      startingAddress: startingAddress,
                                                      endingAddress: endingAddress))
        }
        
        return .init(status: .ok, headers: getDefaultHttpHeader(), body: .init(data: try JSONEncoder().encode(tripsInformation)))
    }
    
    /// Getting trips to export
    private func getToExport(req: Request) async throws -> Response {
        let userAuth = try getUserAuthFor(req)
        let receivedData = try req.content.decode(Trip.ListFilter.self)
        
        guard userAuth.position == .administrator || userAuth.id == receivedData.userID else {
            throw Abort(.unauthorized)
        }
        
        guard let startFilterDate = receivedData.startDate.toDate, let endFilterDate = receivedData.endDate.toDate else {
            throw Abort(.notAcceptable)
        }
        
        var trips = try await Trip.query(on: req.db)
            .filter(\.$user.$id == receivedData.userID)
            .all()
        
        trips = trips.sorted(by: {
            if let firstDate = $0.date.toDate, let secondDate = $1.date.toDate {
                return firstDate.compare(secondDate) == .orderedAscending
            } else {
                return true
            }
        })
        
        var tripList: [[String]] = [[]]
        var totalDistance = 0.0
        
        for trip in trips {
            if let tripDate = trip.date.toDate,
               tripDate <= endFilterDate && tripDate > startFilterDate {
                let startingAddress = try await addressController.getAddressFromId(trip.$startingAddress.id, for: req)
                let endingAddress = try await addressController.getAddressFromId(trip.$endingAddress.id, for: req)
                tripList.append(["\(tripDate.dateOnly)",
                                 "\(startingAddress?.city ?? "No address") -> \(endingAddress?.city ?? "No address")",
                                 "\(trip.missions.joined(separator: ", "))\(trip.comment != nil ? ("\n" + trip.comment!) : "")",
                                 "\(trip.totalDistance.twoDigitPrecision) km"])
                totalDistance += trip.totalDistance
            }
        }
        
        let tripPDF = Trip.PDF(title: receivedData.language == "fr" ? "Déduction fiscale" : "Tax deduction",
                               firstnameTitle: receivedData.language == "fr" ? "Prénom" : "Firstname",
                               lastnameTitle: receivedData.language == "fr" ? "Nom" : "Lastname",
                               phoneTitle: receivedData.language == "fr" ? "Tel." : "Phone",
                               object: receivedData.language == "fr" ? "Cet export recouvre la période du \(startFilterDate.dateOnly) au \(endFilterDate.dateOnly)." : "This export covers the period from \(startFilterDate.dateOnly) to \(endFilterDate.dateOnly).",
                               startTitle: receivedData.language == "fr" ? "Ville de départ" : "Start city",
                               endTitle: receivedData.language == "fr" ? "Ville d'arrivée" : "Destination city",
                               firstname: userAuth.firstname,
                               lastname: userAuth.lastname,
                               email: userAuth.email,
                               phone: userAuth.phoneNumber,
                               totalDistance: "\(totalDistance.twoDigitPrecision)",
                               trips:tripList)
        
        let pages = try [req.view.render("pdf", tripPDF)]
            .flatten(on: req.eventLoop)
            .map({ views in
                views.map { view in
                    Page(view.data)
                }
            }).wait()
        
        let document = Document(margins: 15)
        document.pages = pages
        let pdf = try await document.generatePDF(on: req.application.threadPool, eventLoop: req.eventLoop, title: "\(userAuth.firstname) \(userAuth.lastname)")
        
        return Response(status: .ok, headers: HTTPHeaders([("Content-Type", "application/pdf")]), body: .init(data: pdf))
    }
    
    /// Getitng the chart points
    private func getChartPoint(req: Request) async throws -> Response {
        guard let userId = UUID(uuidString: req.parameters.get("userID") ?? "nul"),
              let filter = req.parameters.get("filter") else {
            throw Abort(.notFound)
        }
        
        let trips = try await Trip.query(on: req.db)
            .filter(\.$user.$id == userId)
            .all()
        
        var latestDistances: [Trip.ChartInfo] = []
        
        if filter == "week" {
            for day in 0...6 {
                latestDistances.append(getDistanceForXDaysAgo(Double(day), trips: trips))
            }
        } else if filter == "month" {
            for week in 0...3 {
                latestDistances.append(getDistanceForXWeekAgo(week, trips: trips))
            }
        } else if filter == "year" {
            for month in 0...11 {
                latestDistances.append(getDistanceForXMonthAgo(month, trips: trips))
            }
        } else {
            throw Abort(.notFound)
        }
        
        return .init(status: .ok, headers: getDefaultHttpHeader(), body: .init(data: try JSONEncoder().encode(latestDistances)))
    }
    
    /// Getting this week and this year news
    private func getNews(req: Request) async throws -> Response {
        guard let userId = UUID(uuidString: req.parameters.get("userID") ?? "nul ") else {
            throw Abort(.notFound)
        }
        
        let trips = try await Trip.query(on: req.db)
            .filter(\.$user.$id == userId)
            .all()
        
        return .init(status: .ok, headers: getDefaultHttpHeader(), body: .init(data: try JSONEncoder().encode(formatNews(for: trips))))
    }
    
    // MARK: Utilities functions
    /// Getting the connected user
    private func getUserAuthFor(_ req: Request) throws -> User {
        return try req.auth.require(User.self)
    }
    
    /// Getting the default HTTP headers
    private func getDefaultHttpHeader() -> HTTPHeaders {
        var headers = HTTPHeaders()
        headers.add(name: .contentType, value: "application/json")
        return headers
    }
    
    /// Getting Chart informations for a specific day
    private func getDistanceForXDaysAgo(_ days: Double, trips: [Trip]) -> Trip.ChartInfo {
        var totalDistance: Double = 0.0
        var dateToFind = ""
        var numberOfTrips = 0
        
        if let date = getDate(with: days) {
            dateToFind = date
            for trip in trips {
                if trip.date.contains(date) {
                    totalDistance += trip.totalDistance
                    numberOfTrips += 1
                }
            }
        }
        
        return Trip.ChartInfo(date: dateToFind, distance: totalDistance, numberOfTrip: numberOfTrips)
    }
    
    /// Getting Chart informations for a specific week
    private func getDistanceForXWeekAgo(_ delta: Int, trips: [Trip]) -> Trip.ChartInfo {
        var totalDistance: Double = 0.0
        var numberOfTrips = 0
        let weekNumberToFind =  Calendar.current.component(.weekOfYear, from: Date()) - delta
        
        for trip in trips {
            if let tripDate = trip.date.toDate,
               Calendar.current.component(.weekOfYear, from: tripDate) == weekNumberToFind {
                totalDistance += trip.totalDistance
                numberOfTrips += 1
            }
        }
        
        return Trip.ChartInfo(date: "Week \(weekNumberToFind)", distance: totalDistance, numberOfTrip: numberOfTrips)
    }
    
    /// Getting Chart informations for a specific month
    private func getDistanceForXMonthAgo(_ delta: Int, trips: [Trip]) -> Trip.ChartInfo {
        var totalDistance: Double = 0.0
        var numberOfTrips = 0
        var monthToFind =  Calendar.current.component(.month, from: Date()) - delta
        var year = Calendar.current.component(.year, from: Date())
        
        if monthToFind <= 0 {
            monthToFind = 12 + monthToFind
            year = year - 1
        }
        
        
        for trip in trips {
            if let tripDate = trip.date.toDate,
               Calendar.current.component(.month, from: tripDate) == monthToFind {
                totalDistance += trip.totalDistance
                numberOfTrips += 1
            }
        }
        
        return Trip.ChartInfo(date: "\(monthToFind)/\(year)", distance: totalDistance, numberOfTrip: numberOfTrips)
    }
    
    /// Getting Chart informations for a specific year
    private func getDistanceForXYearAgo(_ delta: Int, trips: [Trip]) -> Trip.ChartInfo {
        var totalDistance: Double = 0.0
        var numberOfTrips = 0
        let yearToFind =  Calendar.current.component(.year, from: Date()) - delta
        
        for trip in trips {
            if let tripDate = trip.date.toDate,
               Calendar.current.component(.year, from: tripDate) == yearToFind {
                totalDistance += trip.totalDistance
                numberOfTrips += 1
            }
        }
        
        return Trip.ChartInfo(date: "\(yearToFind)", distance: totalDistance, numberOfTrip: numberOfTrips)
    }
    
    /// Format date
    private func getDate(with deltaDay: Double) -> String? {
        return Date().getFormattedDateWithDelta(format: "yyyy-MM-dd", delta: deltaDay)
    }
    
    /// Getting total distance for the last 7 days
    private func formatNews(for trips: [Trip]) -> Trip.News {
        let thisWeekNews = getDistanceForXWeekAgo(0, trips: trips)
        let lastWeekNews = getDistanceForXWeekAgo(1, trips: trips)
        let distancePercentSinceLastWeek: Double = gettingPercentBetween(firstNumber: thisWeekNews.distance, and: lastWeekNews.distance)
        let numberTripPercentSinceLastWeek: Double = gettingPercentBetween(firstNumber: Double(thisWeekNews.numberOfTrip), and: Double(lastWeekNews.numberOfTrip))
        
        let thisYearNews = getDistanceForXYearAgo(0, trips: trips)
        let lastYearNews = getDistanceForXYearAgo(1, trips: trips)
        let distancePercentSinceLastYear: Double = gettingPercentBetween(firstNumber: thisYearNews.distance, and: lastYearNews.distance)
        let numberTripPercentSinceLastYear: Double = gettingPercentBetween(firstNumber: Double(thisYearNews.numberOfTrip), and: Double(lastYearNews.numberOfTrip))
        
        return .init(distanceThisWeek: thisWeekNews.distance,
                     numberOfTripThisWeek: thisWeekNews.numberOfTrip,
                     distanceThisYear: thisYearNews.distance,
                     numberOfTripThisYear: thisYearNews.numberOfTrip,
                     distancePercentSinceLastYear: distancePercentSinceLastYear,
                     distancePercentSinceLastWeek: distancePercentSinceLastWeek,
                     numberTripPercentSinceLastYear: numberTripPercentSinceLastYear,
                     numberTripPercentSinceLastWeek: numberTripPercentSinceLastWeek)
    }
    
    /// Getting percent
    private func gettingPercentBetween(firstNumber: Double, and secondNumber: Double) -> Double {
        if secondNumber == 0 {
            return 1
        } else {
            return (firstNumber-secondNumber)/secondNumber
        }
    }
}
