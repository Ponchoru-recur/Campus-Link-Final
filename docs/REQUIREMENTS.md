Campus Link - Implementation Requirements

1. Core Authentication & User Management


    Email/Password Authentication

        Firebase Authentication integration

        Email/password login system

        Account registration for new users

        Session management and logout functionality

        Domain restriction to @carsu.edu.ph accounts only


    User Profiles

        Display name management (visible in conversations)

        Role display (Faculty/Student)

        Profile information storage in Firestore




2. Class-Specific Communication Channels


    Channel Creation & Management (Faculty)

        Create new class channels for assigned subjects/sections

        Edit channel name and description

        Delete channels

        Channel visibility controls


    Channel Access Control

        Instructors can only post to assigned sections

        Students can only access enrolled courses

        Clear visual separation between channels

        Distinct identifiers and navigation elements


    Channel Member Management (Faculty)

        Add students to class channels

        Remove students from channels

        View channel membership roster




3. Messaging System


    Real-Time Messaging

        Send text messages within channels

        Messages appear immediately without refresh (Firestore real-time sync)

        Message delivery under 1 second

        Support concurrent users without performance degradation


    Message Control Features

        Edit sent messages (within 60 minutes)

        Maintain revision history for edited messages

        Unsend/delete messages (within 60 minutes)

        Show deletion placeholder after unsending


    Message History

        Chronological message display

        Searchable message history within channels

        Keyword search (returns results within 3 seconds for 500 messages)

        Offline access to recently loaded messages


    Read Receipts

        Show when recipients have viewed messages

        Display read status to message senders




4. Priority Messaging System


    Message Priority Tagging

        Categorize messages as "Urgent" or "Standard"

        Visual toggle in message compose area

        Urgent category for exams, quizzes, deadlines

        Different notification handling per priority level


    Notification Controls

        Configurable notification preferences

        Sound settings

        Vibration settings

        Preview behavior options


    Do Not Disturb (DND) Scheduling

        Set custom DND time periods

        Suppress standard notifications during DND

        Urgent messages pass through during DND

        Establish boundaries between academic and personal time




5. Announcement System (Faculty)


    One-Click Announcement Posting

        Broadcast to all enrolled students in a channel

        Efficient single-action delivery

        No navigation through multiple group chats


    Announcement Display

        Distinct visual styling (special background color)

        Badge indicators for announcements

        Clear differentiation from regular messages




6. UI/UX Screens


    Login Screen

        Email input field

        Password input field

        Account registration option

        "Forgot Password" functionality (optional)

        Remember me option


    Home Screen

        List of enrolled channels

        Channel organization by course

        Unread message count per channel

        Recent message preview

        Pull-to-refresh functionality

        Channel search/filter


    Channel Conversation Screen

        Message history (scrollable)

        Message composer with text field

        Send button

        Priority toggle (urgent/standard)

        Announcement button (for faculty)

        Message timestamps

        Sender avatar/name display

        Read receipt indicators

        Edit/delete options (long-press messages)


    Profile & Settings Screen

        Display name editor

        Notification preferences

        Do Not Disturb scheduling

        Account logout

        Help menu with contextual guidance

        About/version information




7. Push Notifications


    Firebase Cloud Messaging Integration

        Real-time push notifications

        Urgent vs. standard notification handling

        DND-aware notification delivery

        Notification tap opens relevant channel




8. Data & Security


    Firestore Database Structure

        Users collection

        Channels collection

        Messages subcollection per channel

        Notification settings per user


    Security Rules

        @carsu.edu.ph domain validation

        Channel access authorization

        Message read/write permissions


    Offline Support

        Local caching of recent messages

        Automatic sync when connectivity returns

        Graceful handling of network interruptions




9. Cross-Platform Compatibility - DO NOT BOTHER TOO MUCH ON THIS

    Android Support

        Minimum SDK: Android 5.0 (API level 21)

        Touch-based interactions

        Haptic feedback (vibration)


    iOS Support

        Minimum iOS 12.0

        Native iOS UI patterns

        Consistent experience with Android




10. User Documentation


    In-App Help

        Help menu within each screen

        Tooltips for non-obvious features

        Explanatory text for functionality


    External Documentation

        Quick-start guide PDF (account creation, navigation, messaging basics)
