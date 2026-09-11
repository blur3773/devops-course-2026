# Инструменты Девопс — контрольная работа 1

**Изосимов Максим Игоревич · ЭФБО-11-24 · РТУ МИРЭА · 2026/2027**

Учебный проект **StudyTasks**: консольный планировщик и инфраструктура разработки с Git и GitHub.

## Материалы контрольной

- [Документация и структура проекта](docs/README.md)
- [Доска задач](TASKS.md) и [GitHub Issues](https://github.com/blur3773/devops-course-2026/issues)
- [Сведения о студенте](about_me.md) и [цели семестра](goals.md)
- [Ответы на контрольные вопросы](docs/self-check.md)
- [Сравнение Git и SVN](svn_comparison.md)
- [Соответствие методичкам](docs/methodology.md)

## Быстрый старт

Требуется Python 3.10+. Сторонних зависимостей нет.

```bash
git clone git@github.com:blur3773/devops-course-2026.git
cd devops-course-2026
python3 -m src.main add "Подготовить отчёт по DevOps"
python3 -m src.main list
python3 -m src.main done 1
python3 -m unittest discover -s tests -v
```

Если порт SSH 22 недоступен, GitHub поддерживает SSH через `ssh.github.com:443`; HTTPS-клон также доступен по адресу `https://github.com/blur3773/devops-course-2026.git`.

## Порядок разработки

Работа ведётся в отдельных ветках через Pull Request. Для парного учебного Code Review нужен независимый участник. Состояния задач и реальные подтверждения выполнения отражаются в отчёте.
