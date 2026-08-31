CREATE TABLE form_templates (
  form_id TEXT PRIMARY KEY REFERENCES forms(form_id),
  schema_version TEXT NOT NULL,
  template_json TEXT NOT NULL,
  instructions TEXT,
  render_status TEXT NOT NULL CHECK (render_status IN ('ready', 'needs_review')),
  provenance_json TEXT NOT NULL DEFAULT '{}',
  review_reason TEXT
);
