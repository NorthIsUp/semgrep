# PEP 758 (Python 3.14): in 'except A, B:' the second element is another
# exception type, not a variable bound to the exception (that was Python 2).

# ERROR:
try:
  pass
except ValueError as e:
  pass

# OK: 'TypeError' is a type here, it is not bound to anything
try:
  pass
except ValueError, TypeError:
  pass
