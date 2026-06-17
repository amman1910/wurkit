# WURKIT

## Overview

**WURKIT** is a Flutter + Firebase mobile application designed to connect employees looking for short-term and one-day jobs with employers who need temporary workers quickly.

The platform helps businesses fill urgent staffing gaps while giving workers the opportunity to find flexible same-day work opportunities.

Examples include:

* Waiters
* Cleaners
* Dishwashers
* Dog Walkers
* Babysitters
* Delivery Workers
* Event Staff
* Temporary Labor

---

# Problem Statement

Many businesses experience unexpected employee absences and need immediate replacements.

At the same time, many workers have free time and are willing to work for a single day but have no efficient way to find available opportunities.

WURKIT bridges this gap by providing a fast and simple marketplace for temporary employment.

---

# Key Features

## Employee Features

### Account Management

* Register and Login
* Google Authentication
* Personal Profile

### Job Discovery

* Browse available jobs
* View detailed job information
* Apply for jobs

### Applications

* Track submitted applications
* View application status

### Communication

* Real-time chat with employers

### Reviews & Ratings

* Rate employers after working
* View employer ratings and reviews
* View personal ratings

### Reporting System

* Report employers
* Report jobs
* Report users from chat

---

## Employer Features

### Business Profile

* Employer registration
* Business profile management

### Job Management

* Create job postings
* Manage active jobs
* View applicants

### Application Management

* Approve applicants
* Reject applicants

### Communication

* Real-time chat with employees

### Reviews & Ratings

* Rate employees
* View employee ratings and reviews

### Reporting System

* Report employees
* Report users from chat

---

# Admin Dashboard

The system includes a dedicated Admin Dashboard.

## Overview

* Total Employees
* Total Employers
* Total Users
* Open Jobs
* Closed Jobs
* Total Applications
* Total Reviews
* Total Reports
* Pending Reports

## User Management

* View users
* Block / Unblock users
* Verify users

## Job Management

* View all jobs
* Close jobs manually

## Review Management

* View reviews
* Delete inappropriate reviews

## Reports Management

* Review submitted complaints
* Mark reports as:

  * Pending
  * Reviewed
  * Resolved
  * Dismissed
* Add admin notes

## Category Management

* Add categories
* Enable / Disable categories

---

# Technology Stack

## Frontend

* Flutter
* Dart

## Backend

* Firebase

### Firebase Services

* Firebase Authentication
* Cloud Firestore
* Firebase Storage (optional)
* Firebase Cloud Messaging (future)

---

# Firestore Collections

Main collections used in the project:

```text
users
employeeProfiles
employerProfiles
jobs
applications
reviews
reports
jobCategories
chats
messages
```

# Project Structure

```text
lib/
│
├── core/
│
├── features/
│   ├── authentication/
│   ├── employee_home/
│   ├── employer_home/
│   ├── jobs/
│   ├── applications/
│   ├── messages/
│   ├── reviews/
│   ├── reports/
│   └── admin/
│
├── services/
│
└── main.dart
```

# Installation

## Clone Repository

```bash
git clone <repository-url>
cd wurkit
```

## Install Dependencies

```bash
flutter pub get
```

## Run Application

```bash
flutter run
```

---

# Future Improvements

* Available Now employees
* Favorite workers
* Advanced job filtering
* Location-based recommendations
* Push notifications
* AI-powered job matching
* Employee availability scheduling

---

# Authors

Software Engineering Graduation Project

Team Members:

* Ahmad Abu Gosh
* Amir Mana

---

# License

This project was developed for educational and academic purposes.
