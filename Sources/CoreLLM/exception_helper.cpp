#include "exception_helper.h"
#include <stdexcept>

void throw_exception(const char* description){
    throw std::invalid_argument(description);
}
