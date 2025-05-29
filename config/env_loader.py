import os
import warnings
from typing import Type, Optional
from .logger import get_logger

logger = get_logger(__name__)

def get_env_variable(
        name: str,
        default: Optional[str] = None,
        cast: Type = str,
        required: bool = False
    ):
    """
    Retrieve and cast an environment variable, with optional default and requirement enforcement.

    Args:
        name: Name of the environment variable to fetch.
        default: Default value to use if the variable is not set.
        cast: Callable to cast the string value to the desired type (e.g., int, float, bool).
        required: If True and the variable is missing without a default, raises ValueError.

    Returns:
        The casted value of the environment variable, or the default if not set and not required.

    Raises:
        ValueError: If the variable is required but missing, or if casting fails.
    """
    raw = os.getenv(name, None)
    if raw is None:
        if required and default is None:
            warnings.warn(f"Warning: {name} is not set and no default is provided.")
            raise ValueError(f"Missing required environment variable: {name}")
        logger.warning(f"{name} not set; using default: {default!r}")
        raw = default
    try:
        return cast(raw) if raw is not None else None
    except Exception as e:
        raise ValueError(f"Failed to cast {name}={raw!r} to {cast}: {e}")
    