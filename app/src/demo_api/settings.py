"""Runtime settings that are safe to expose through the build-info endpoint."""

from __future__ import annotations

import os
from dataclasses import dataclass

DEFAULT_APP_NAME = "devsecops-demo-api"
DEFAULT_VERSION = "dev"
DEFAULT_GIT_SHA = "unknown"


@dataclass(frozen=True, slots=True)
class Settings:
    """Non-sensitive application metadata supplied by the deployment."""

    app_name: str = DEFAULT_APP_NAME
    version: str = DEFAULT_VERSION
    git_sha: str = DEFAULT_GIT_SHA

    @classmethod
    def from_environment(cls) -> Settings:
        """Build settings from the explicitly supported environment variables."""

        return cls(
            app_name=os.getenv("APP_NAME", DEFAULT_APP_NAME),
            version=os.getenv("APP_VERSION", DEFAULT_VERSION),
            git_sha=os.getenv("GIT_SHA", DEFAULT_GIT_SHA),
        )
