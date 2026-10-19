# Desktop apps for the search pane, built on fabric's DesktopApp helpers.
from fabric.utils import get_desktop_applications


def list_apps():
    apps = get_desktop_applications()
    apps.sort(key=lambda app: shown_name(app).lower())
    return apps


def shown_name(app):
    return app.display_name or app.name or ""


def binary_of(app):
    if not app.executable:
        return ""
    return app.executable.rsplit("/", 1)[-1]


def haystack(app):
    return " ".join([shown_name(app), app.generic_name or "", binary_of(app)]).lower()


def score_app(query, app):
    name = shown_name(app).lower()
    binary = binary_of(app).lower()
    if name == query or binary == query:
        return 100
    if name.startswith(query) or binary.startswith(query):
        return 80
    if query in name or query in binary:
        return 40
    return 0
