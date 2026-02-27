# ABAP-Exercise-Platform
ABAP Exercise Platform is used in the SAP GUI 
<div align="right">
  <strong>English</strong> | <a href="./README_zh.md">简体中文</a>
</div>

## Overview
The **ABAP Exercise Platform** is an interactive, SAP GUI-based coding platform. It allows developers to learn, practice, and test ABAP code directly within their SAP environment. Instructors can seamlessly create coding challenges, while users can solve them and view successful solutions from their peers.

## System Requirements
* **SAP NetWeaver / ABAP Platform**: Version **>= 7.54**.

## Features

* **Exercise Maintenance (`ZRPEX001`)**: An instructor dashboard to create, edit, load, save, and delete coding exercises. It features split-screen editors to maintain problem descriptions in HTML, initial ABAP boilerplate code, and hidden ABAP Unit Test logic.
* **Interactive Coding Environment (`ZRPEXERCISE002`)**: The core practice platform where users browse exercises via an ALV grid. Upon selecting a challenge, users are presented with an HTML viewer for the problem statement and an ABAP editor to write their solution.
* **Dynamic Code Evaluation**: When a user runs tests, the platform merges their submission with the hidden test code and executes it dynamically using `GENERATE SUBROUTINE POOL`. Results (Pass/Fail) are injected directly into the HTML viewer for immediate visual feedback.
* **Solution Sharing (`ZRPEXERCISE003`)**: A collaborative learning space that displays a list of all successful submissions. Users can view the exact code submitted by others to learn different approaches to the same problem.
* **Data Backup & Restore (`ZRPEXERCISE_DOWNLOAD` / `ZRPEXERCISE_UPLOAD`)**: Built-in utilities to download exercise metadata and user submissions as XML files to the local frontend, and upload them back into the database.
* **Unit Testing Utility (`ZCL_EXERCISE_UNIT_TEST`)**: A dedicated class to log assertions (`assert_equals`) and track test execution results during the dynamic evaluation.

## Database Architecture
The platform relies on two primary transparent tables:
* `ZTEX_DESC`: Stores exercise metadata, including the HTML description, initial template code, and testing logic.
* `ZTEX_SUBMISSION`: Tracks user submissions, saving the user ID, submitted ABAP code, and the timestamp of their first successful attempt.

## License
This project is licensed under the MIT License.
