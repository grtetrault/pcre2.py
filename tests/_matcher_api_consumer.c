#define PY_SSIZE_T_CLEAN
#include <Python.h>
#include "matcher_api.h"

typedef struct {
    PyObject *provider;
    PyObject *capsule;
    const Pcre2MatcherAPI *api;
} ConsumerState;

static ConsumerState *
get_state(PyObject *module)
{
    ConsumerState *state = PyModule_GetState(module);
    if (state->api != NULL) {
        return state;
    }
    PyObject *provider = PyImport_ImportModule("pcre2._cy");
    if (provider == NULL) {
        return NULL;
    }
    PyObject *capsule = PyObject_GetAttrString(provider, "_MATCHER_API_v1");
    if (capsule == NULL) {
        Py_DECREF(provider);
        return NULL;
    }
    const Pcre2MatcherAPI *api = PyCapsule_GetPointer(capsule, PCRE2_MATCHER_API_NAME);
    if (api == NULL) {
        Py_DECREF(capsule);
        Py_DECREF(provider);
        return NULL;
    }
    if (api->abi_version != PCRE2_MATCHER_API_VERSION ||
            api->struct_size < sizeof(Pcre2MatcherAPI) ||
            api->matcher_type == NULL || api->new_matcher == NULL || api->search == NULL) {
        Py_DECREF(capsule);
        Py_DECREF(provider);
        PyErr_SetString(PyExc_RuntimeError, "Incompatible matcher API");
        return NULL;
    }
    state->provider = provider;
    state->capsule = capsule;
    state->api = api;
    return state;
}

static PyObject *
prepare(PyObject *module, PyObject *args)
{
    PyObject *pattern, *type = NULL, *provider = NULL;
    if (!PyArg_ParseTuple(args, "O|OO", &pattern, &type, &provider)) {
        return NULL;
    }
    ConsumerState *state = get_state(module);
    if (state == NULL) {
        return NULL;
    }
    if (type == NULL) {
        type = (PyObject *)state->api->matcher_type;
    }
    if (!PyType_Check(type)) {
        PyErr_SetString(PyExc_TypeError, "Expected a matcher type");
        return NULL;
    }
    return state->api->new_matcher(
        (PyTypeObject *)type, pattern, provider == NULL ? state->provider : provider);
}

static PyObject *
search(PyObject *module, PyObject *args)
{
    PyObject *matcher, *subject;
    if (!PyArg_ParseTuple(args, "OO", &matcher, &subject)) {
        return NULL;
    }
    ConsumerState *state = get_state(module);
    if (state == NULL) {
        return NULL;
    }
    int result = state->api->search(matcher, subject);
    if (result < 0) {
        return NULL;
    }
    return PyBool_FromLong(result);
}

/* Both loops share the input and counting overhead. The public path caches
 * Pattern.search once, then releases each Match result before the next call. */
static PyObject *
count_matches(PyObject *module, PyObject *args)
{
    PyObject *matcher, *subjects;
    int public = 0;
    if (!PyArg_ParseTuple(args, "OO|p", &matcher, &subjects, &public)) {
        return NULL;
    }
    ConsumerState *state = get_state(module);
    if (state == NULL) {
        return NULL;
    }
    PyObject *sequence = PySequence_Fast(subjects, "Expected a sequence");
    if (sequence == NULL) {
        return NULL;
    }
    PyObject *method = public ? PyObject_GetAttrString(matcher, "search") : NULL;
    if (public && method == NULL) {
        Py_DECREF(sequence);
        return NULL;
    }
    Py_ssize_t count = 0;
    for (Py_ssize_t i = 0; i < PySequence_Fast_GET_SIZE(sequence); i++) {
        PyObject *subject = PySequence_Fast_GET_ITEM(sequence, i);
        int result;
        if (public) {
            PyObject *match = PyObject_CallFunctionObjArgs(method, subject, NULL);
            if (match == NULL) {
                goto error;
            }
            result = match != Py_None;
            Py_DECREF(match);
        }
        else {
            result = state->api->search(matcher, subject);
            if (result < 0) {
                goto error;
            }
        }
        count += result;
    }
    Py_XDECREF(method);
    Py_DECREF(sequence);
    return PyLong_FromSsize_t(count);

error:
    Py_XDECREF(method);
    Py_DECREF(sequence);
    return NULL;
}

static int
traverse(PyObject *module, visitproc visit, void *arg)
{
    ConsumerState *state = PyModule_GetState(module);
    Py_VISIT(state->provider);
    Py_VISIT(state->capsule);
    return 0;
}

static int
clear(PyObject *module)
{
    ConsumerState *state = PyModule_GetState(module);
    state->api = NULL;
    Py_CLEAR(state->capsule);
    Py_CLEAR(state->provider);
    return 0;
}

static PyMethodDef methods[] = {
    {"prepare", prepare, METH_VARARGS, NULL},
    {"search", search, METH_VARARGS, NULL},
    {"count_matches", count_matches, METH_VARARGS, NULL},
    {NULL, NULL, 0, NULL}
};

static PyModuleDef module = {
    PyModuleDef_HEAD_INIT,
    "_matcher_api_consumer",
    NULL,
    sizeof(ConsumerState),
    methods,
    NULL,
    traverse,
    clear,
    NULL
};

PyMODINIT_FUNC
PyInit__matcher_api_consumer(void)
{
    return PyModule_Create(&module);
}
