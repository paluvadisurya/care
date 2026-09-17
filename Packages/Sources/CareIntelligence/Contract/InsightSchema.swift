import Foundation
import CareCore

/// The strict JSON schema for `care_insight`, passed to OpenAI as `text.format` and shown to DeepSeek in the prompt.
public enum InsightSchema {
    public static let name = "care_insight"

    public static let json = """
    {
      "type": "object",
      "additionalProperties": false,
      "required": ["scope","tone","headline","blocks","reminders","evidence"],
      "properties": {
        "scope": { "type": "string", "enum": ["person","module","home","weekly"] },
        "tone":  { "type": "string", "enum": ["positive","neutral","attention"] },
        "headline": { "type": "string" },
        "blocks": {
          "type": "array",
          "items": { "anyOf": [
            { "$ref": "#/$defs/stat" }, { "$ref": "#/$defs/trend" }, { "$ref": "#/$defs/countdown" },
            { "$ref": "#/$defs/list" }, { "$ref": "#/$defs/action" }, { "$ref": "#/$defs/insight" },
            { "$ref": "#/$defs/mood_strip" }, { "$ref": "#/$defs/talking_points" },
            { "$ref": "#/$defs/compare" }, { "$ref": "#/$defs/note" }
          ] }
        },
        "reminders": {
          "type": "array",
          "items": { "type": "object", "additionalProperties": false,
            "required": ["fire_at","message","reason","module","person_id"],
            "properties": {
              "fire_at": { "type": "string", "description": "ISO 8601 local time" },
              "message": { "type": "string" },
              "reason":  { "type": "string" },
              "module":  { "type": "string" },
              "person_id": { "type": "string" } } }
        },
        "evidence": { "type": "array", "items": { "type": "string" } }
      },
      "$defs": {
        "stat": { "type": "object", "additionalProperties": false,
          "required": ["type","label","value","trend","tone"],
          "properties": { "type": {"type":"string","enum":["stat"]}, "label": {"type":"string"}, "value": {"type":"string"},
            "trend": {"type":["string","null"], "enum":["up","down","flat",null]}, "tone": {"type":"string","enum":["good","neutral","attention"]} } },
        "trend": { "type": "object", "additionalProperties": false,
          "required": ["type","label","points","annotation"],
          "properties": { "type": {"type":"string","enum":["trend"]}, "label": {"type":"string"},
            "points": {"type":"array","items":{"type":"number"}}, "annotation": {"type":["string","null"]} } },
        "countdown": { "type": "object", "additionalProperties": false,
          "required": ["type","title","date"], "properties": { "type": {"type":"string","enum":["countdown"]}, "title": {"type":"string"}, "date": {"type":"string"} } },
        "list": { "type": "object", "additionalProperties": false,
          "required": ["type","title","items"], "properties": { "type": {"type":"string","enum":["list"]}, "title": {"type":"string"},
            "items": {"type":"array","items":{"type":"object","additionalProperties":false,"required":["text","entry_id"],
              "properties":{"text":{"type":"string"},"entry_id":{"type":["string","null"]}}}} } },
        "action": { "type": "object", "additionalProperties": false,
          "required": ["type","title","reason","deeplink"], "properties": { "type": {"type":"string","enum":["action"]}, "title": {"type":"string"},
            "reason": {"type":"string"}, "deeplink": {"type":"string", "description":"care://person/{id}/{module}/new?title=..."} } },
        "insight": { "type": "object", "additionalProperties": false,
          "required": ["type","text","evidence_ids"], "properties": { "type": {"type":"string","enum":["insight"]}, "text": {"type":"string"},
            "evidence_ids": {"type":"array","items":{"type":"string"}} } },
        "mood_strip": { "type": "object", "additionalProperties": false,
          "required": ["type","label","values"], "properties": { "type": {"type":"string","enum":["mood_strip"]}, "label": {"type":"string"},
            "values": {"type":"array","items":{"type":["integer","null"]}} } },
        "talking_points": { "type": "object", "additionalProperties": false,
          "required": ["type","items"], "properties": { "type": {"type":"string","enum":["talking_points"]}, "items": {"type":"array","items":{"type":"string"}} } },
        "compare": { "type": "object", "additionalProperties": false,
          "required": ["type","label","a_label","a","b_label","b"], "properties": { "type": {"type":"string","enum":["compare"]}, "label": {"type":"string"},
            "a_label": {"type":"string"}, "a": {"type":"number"}, "b_label": {"type":"string"}, "b": {"type":"number"} } },
        "note": { "type": "object", "additionalProperties": false,
          "required": ["type","text"], "properties": { "type": {"type":"string","enum":["note"]}, "text": {"type":"string"} } }
      }
    }
    """

    /// The schema as a JSON tree, ready to embed in a request body.
    public static var value: JSONValue {
        (try? PayloadCoder.decoder.decode(JSONValue.self, from: Data(json.utf8))) ?? .object([:])
    }

    /// Round-trip check used by tests: the schema must parse and name every block kind.
    public static var coversEveryBlockKind: Bool {
        let defs = value["$defs"]?.objectValue ?? [:]
        let names = Set(defs.keys)
        return InsightBlockKind.allCases.filter { $0 != .headline }.allSatisfy { names.contains($0.rawValue) }
    }
}
