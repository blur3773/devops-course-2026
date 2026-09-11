"""Минимальный CLI для списка учебных задач; только стандартная библиотека."""

import argparse
import json
from pathlib import Path


def read_tasks(path):
    if not path.exists():
        return []
    tasks = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(tasks, list) or any(
        not isinstance(item, dict)
        or type(item.get("id")) is not int
        or item["id"] < 1
        or not isinstance(item.get("title"), str)
        or not item["title"].strip()
        or type(item.get("done")) is not bool
        for item in tasks
    ):
        raise ValueError("Некорректный формат файла задач")
    if len({item["id"] for item in tasks}) != len(tasks):
        raise ValueError("Повторяющиеся идентификаторы задач")
    return tasks


def save_tasks(path, tasks):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(tasks, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main(argv=None):
    parser = argparse.ArgumentParser(description="StudyTasks — учебный планировщик")
    parser.add_argument("--file", type=Path, default=Path("data/tasks.json"))
    commands = parser.add_subparsers(dest="command", required=True)
    add = commands.add_parser("add", help="Добавить задачу")
    add.add_argument("title")
    commands.add_parser("list", help="Показать задачи")
    done = commands.add_parser("done", help="Завершить задачу")
    done.add_argument("id", type=int)
    args = parser.parse_args(argv)
    try:
        tasks = read_tasks(args.file)
        if args.command == "add":
            title = args.title.strip()
            if not title:
                raise ValueError("Название задачи не должно быть пустым")
            task = {"id": max((item["id"] for item in tasks), default=0) + 1,
                    "title": title, "done": False}
            tasks.append(task)
            save_tasks(args.file, tasks)
            print(f"Добавлена задача #{task['id']}: {title}")
        elif args.command == "done":
            task = next((item for item in tasks if item["id"] == args.id), None)
            if task is None:
                raise ValueError(f"Задача #{args.id} не найдена")
            task["done"] = True
            save_tasks(args.file, tasks)
            print(f"Завершена задача #{args.id}")
        else:
            if not tasks:
                print("Задач пока нет")
            for task in tasks:
                print(f"[{'x' if task['done'] else ' '}] #{task['id']} {task['title']}")
    except (OSError, ValueError) as error:
        parser.exit(1, f"Ошибка: {error}\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
