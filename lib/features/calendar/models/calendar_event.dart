import 'package:flutter/material.dart';

class CalendarEvent {
  final String id;
  final String title;
  final String type; // 'task', 'content', 'milestone', 'meeting', 'project'
  final DateTime date;
  final Color color;
  final String? description;
  final String? assignee;
  final String? priority; // 'low','medium','high','urgent'
  final bool isAiGenerated;

  const CalendarEvent({
    required this.id,
    required this.title,
    required this.type,
    required this.date,
    required this.color,
    this.description,
    this.assignee,
    this.priority,
    this.isAiGenerated = false,
  });

  CalendarEvent copyWith({
    String? id,
    String? title,
    String? type,
    DateTime? date,
    Color? color,
    String? description,
    String? assignee,
    String? priority,
    bool? isAiGenerated,
  }) {
    return CalendarEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      type: type ?? this.type,
      date: date ?? this.date,
      color: color ?? this.color,
      description: description ?? this.description,
      assignee: assignee ?? this.assignee,
      priority: priority ?? this.priority,
      isAiGenerated: isAiGenerated ?? this.isAiGenerated,
    );
  }
}

class AgencyProject {
  final String id;
  final String name;
  final String month;
  final int monthNumber;
  final Color color;
  final String? description;

  const AgencyProject({
    required this.id,
    required this.name,
    required this.month,
    required this.monthNumber,
    required this.color,
    this.description,
  });
}
