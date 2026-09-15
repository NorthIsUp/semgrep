# PEP 758 (Python 3.14): 'except A, B:' is the same as 'except (A, B):'.
# https://github.com/semgrep/semgrep/issues/11906

# ERROR:
try:
  pass
except ValueError, TypeError:
  pass

# three types, which used to be a parse error
# ERROR:
try:
  pass
except TypeError, ValueError, KeyError:
  pass

# the parenthesized form, as a control
# ERROR:
try:
  pass
except (TypeError, ValueError):
  pass

def f():
  # same thing, but nested in a function like in the original bug report
  # ERROR:
  try:
    pass
  except ValueError, TypeError:
    pass

# OK: none of the exception types here is the one we look for
try:
  pass
except TypeError, KeyError:
  pass
