import numpy as np
from model.python_study import detailed_metrics


def test_per_class_metrics_include_unpredicted_and_absent_classes():
    result = detailed_metrics(np.array([0, 0, 1, 1]), np.array([0, 1, 1, 1]), ['a', 'b', 'c'])
    assert result['accuracy'] == .75
    assert result['per_class'][0]['precision'] == 1.
    assert result['per_class'][0]['recall'] == .5
    assert result['per_class'][1]['precision'] == 2 / 3
    assert result['per_class'][2] == {'label': 'c', 'support': 0, 'precision': 0., 'recall': 0., 'f1': 0.}
