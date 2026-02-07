#!/usr/bin/env python3
"""
Export NotebookLM notebook to Anki flashcard format.
Converts quiz and flashcard artifacts to CSV for Anki import.
"""
import csv
import json
import os
import sys
from pathlib import Path


def export_to_anki(notebook_dir: str, output_dir: str):
    """Export notebook to Anki format (CSV with Front,Back,Tags)."""
    notebook_path = Path(notebook_dir)
    output_path = Path(output_dir)
    output_path.mkdir(parents=True, exist_ok=True)

    # Read metadata for tags
    with open(notebook_path / "metadata.json") as f:
        metadata = json.load(f)

    notebook_title = metadata.get("title", "NotebookLM")
    tag = notebook_title.replace(" ", "_")

    cards = []

    # Process quiz artifacts
    quiz_dir = notebook_path / "studio" / "interactive"
    if quiz_dir.exists():
        for quiz_file in quiz_dir.glob("*-quiz.json"):
            with open(quiz_file) as f:
                quiz_data = json.load(f)

            questions = quiz_data.get("questions", [])
            for q in questions:
                question = q.get("question", "")
                answer = q.get("answer", "")
                if question and answer:
                    cards.append({
                        "Front": question,
                        "Back": answer,
                        "Tags": f"{tag} quiz"
                    })

    # Process flashcard artifacts
    flashcard_dir = notebook_path / "studio" / "interactive"
    if flashcard_dir.exists():
        for flashcard_file in flashcard_dir.glob("*-flashcards.json"):
            with open(flashcard_file) as f:
                flashcard_data = json.load(f)

            cards_list = flashcard_data.get("cards", [])
            for card in cards_list:
                front = card.get("front", "")
                back = card.get("back", "")
                if front and back:
                    cards.append({
                        "Front": front,
                        "Back": back,
                        "Tags": f"{tag} flashcard"
                    })

    # Write CSV
    output_file = output_path / "anki-import.csv"
    with open(output_file, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=["Front", "Back", "Tags"])
        writer.writeheader()
        writer.writerows(cards)

    print(f"Anki CSV: {output_file} ({len(cards)} cards)")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: export_anki.py <notebook-dir> <output-dir>")
        sys.exit(1)

    export_to_anki(sys.argv[1], sys.argv[2])
