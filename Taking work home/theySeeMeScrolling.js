// so, scrolling stuff
// the idea is to write a function that can scroll the form to a specific element,
// usually a field, or a button, maybe a grop header
// It's probably good enough to have one scrolling function, and do the conversion in the function call
// i.e.: scrollToElement(getFormElement(fildName)) or directly like scrollToElement(elementName)

function scrollToFormElement(elementName) {
  // scrolling is done here
  // we measure the distance from the top of the container form_space and offset it with 40 pixels for the header
}

//call example
let fieldName = "testField";
//make sure we account for xpath and field name
//if only the name was passed, convert it to xpath - otherwise leave it as is
if (Utils.getNameFromPath(":", fieldName) == fieldName) {
  fieldName = $celaneseCustomJS.getXpath(fieldName);
}
//we can get the binding (data-link)
scrollToFormElement(Uitls.formatBindingFromXpath(fieldName));

//also, we can call this with something like this
scrollToFormElement($j(".required_field").first());
//which allows us to scroll to the first instance of an elemenet in a class
//in practice, this can be used to scroll to the first field with a validation error - provided I check what the class name is